class AdminConfiguration
  include Mongoid::Document
  field :config_type, type: String
  field :value_type, type: String
  field :multiplier, type: String
  field :value, type: String

  validates_uniqueness_of :config_type, message: ": '%{value}' has already been set.  Please edit the corresponding entry to update."

  validate :validate_value_by_type

  FIRECLOUD_ACCESS_NAME = 'FireCloud Access'
  NUMERIC_VALS = %w(byte kilobyte megabyte terabyte petabyte exabyte)

  # really only used for IDs in the table...
  def url_safe_name
    self.config_type.downcase.gsub(/[^a-zA-Z0-9]+/, '-').chomp('-')
  end

  def self.config_types
    ['Daily User Download Quota']
  end

  def self.value_types
    ['Numeric', 'Boolean', 'String']
  end

  def self.current_firecloud_access
    status = AdminConfiguration.find_by(config_type: AdminConfiguration::FIRECLOUD_ACCESS_NAME)
    if status.nil?
      'on'
    else
      status.value
    end
  end

  def self.firecloud_access_enabled?
    status = AdminConfiguration.find_by(config_type: AdminConfiguration::FIRECLOUD_ACCESS_NAME)
    if status.nil?
      true
    else
      status.value == 'on'
    end
  end

  # display value formatted by type
  def display_value
    case self.value_type
      when 'Numeric'
        unless self.multiplier.nil? || self.multiplier.blank?
          "#{self.value} #{self.multiplier}(s) <span class='badge'>#{self.convert_value_by_type} bytes</span>"
        else
          self.value
        end
      else
        self.value == '1' ? 'Yes' : 'No'
    end
  end

  # converter to return requested value as an instance of its value type
  # numerics will return an interger or float depending on value contents (also understands Rails shorthands for byte size increments)
  # booleans return true/false based on matching a variety of possible 'true' values
  # strings just return themselves
  def convert_value_by_type
    case self.value_type
      when 'Numeric'
        unless self.multiplier.nil? || self.multiplier.blank?
          val = self.value.include?('.') ? self.value.to_f : self.value.to_i
          return val.send(self.multiplier.to_sym)
        else
          return self.value.to_f
        end
      when 'Boolean'
        return self.value == '1'
      else
        return self.value
    end
  end

  # method that disables access by revoking permissions to studies directly in FireCloud
  def self.configure_firecloud_access(status)
    case status
      when 'readonly'
        @config_setting = 'READER'
      when 'off'
        @config_setting = 'NO ACCESS'
      else
        @config_setting = 'ERROR'
    end
    unless @config_setting == 'ERROR'
      Rails.logger.info "#{Time.now}: setting access on all studies to #{@config_setting}"
      # only use studies not queued for deletion; those have already had access revoked
      Study.not_in(queued_for_deletion: true).each do |study|
        Rails.logger.info "#{Time.now}: begin revoking access to study: #{study.name}"
        # first remove share access
        shares = study.study_shares.map(&:email)
        shares.each do |user|
          Rails.logger.info "#{Time.now}: revoking share access for #{user}"
          revoke_share_acl = Study.firecloud_client.create_workspace_acl(user, @config_setting)
          Study.firecloud_client.update_workspace_acl(study.firecloud_workspace, revoke_share_acl)
        end
        # last, remove study owner access
        owner = study.user.email
        Rails.logger.info "#{Time.now}: revoking owner access for #{owner}"
        revoke_owner_acl = Study.firecloud_client.create_workspace_acl(owner, @config_setting)
        Study.firecloud_client.update_workspace_acl(study.firecloud_workspace, revoke_owner_acl)
        Rails.logger.info "#{Time.now}: access revocation for #{study.name} complete"
      end
      Rails.logger.info "#{Time.now}: all study access set to #{@config_setting}"
    else
      Rails.logger.info "#{Time.now}: invalid status setting: #{status}; aborting"
    end
  end

  # method that re-enables access by restoring permissions to studies directly in FireCloud
  def self.enable_firecloud_access
    Rails.logger.info "#{Time.now}: restoring access to all studies"
    # only use studies not queued for deletion; those have already had access revoked
    Study.not_in(queued_for_deletion: true).each do |study|
      Rails.logger.info "#{Time.now}: begin restoring access to study: #{study.name}"
      # first remove share access
      shares = study.study_shares
      shares.each do |share|
        user = share.email
        share_permission = StudyShare::FIRECLOUD_ACL_MAP[share.permission]
        Rails.logger.info "#{Time.now}: restoring #{share_permission} permission for #{user}"
        restore_share_acl = Study.firecloud_client.create_workspace_acl(user, share_permission)
        Study.firecloud_client.update_workspace_acl(study.firecloud_workspace, restore_share_acl)
      end
      # last, remove study owner access
      owner = study.user.email
      Rails.logger.info "#{Time.now}: restoring owner access for #{owner}"
      restore_owner_acl = Study.firecloud_client.create_workspace_acl(owner, 'OWNER')
      Study.firecloud_client.update_workspace_acl(study.firecloud_workspace, restore_owner_acl)
      Rails.logger.info "#{Time.now}: access restoration for #{study.name} complete"
    end
    Rails.logger.info "#{Time.now}: all study access restored"
  end

  # sends an email to all site administrators on startup notifying them of portal restart
  def self.restart_notification
    current_time = Time.now.to_s(:long)
    locked_jobs = Delayed::Job.where(:locked_by.nin => [nil]).count
    message = "<p>The Single Cell Portal was restarted at #{current_time}.</p><p>There are currently #{locked_jobs} jobs waiting to be restarted.</p>"
    SingleCellMailer.admin_notification('Portal restart', nil, message).deliver_now
  end

  # method to unlock all current delayed_jobs to allow them to be restarted
  def self.restart_locked_jobs
    # determine current processes and their pids
    job_count = 0
    pid_files = Dir.entries(Rails.root.join('tmp','pids')).delete_if {|p| p.start_with?('.')}
    pids = {}
    pid_files.each do |file|
      pids[file.chomp('.pid')] = File.open(Rails.root.join('tmp', 'pids', file)).read.strip
    end
    locked_jobs = Delayed::Job.where(:locked_by.nin => [nil]).to_a
    locked_jobs.each do |job|
      # grab worker number and pid
      worker, pid_str = job.locked_by.split.minmax
      pid = pid_str.split(':').last
      # check if current job worker has matching pid; if not, then the job is orphaned and should be unlocked
      unless pids[worker] == pid
        # deserialize handler object to get attributes for logging
        deserialized_handler = YAML::load(job.handler)
        job_method = deserialized_handler.method_name.to_s
        Rails.logger.info "#{Time.now}: Restarting orphaned process #{job.id}:#{job_method} initially queued on #{job.created_at.to_s(:long)}"
        job.update(locked_by: nil, locked_at: nil)
        job_count += 1
      end
    end
    job_count
  end

  private

  def validate_value_by_type
    case self.value_type
      when 'Numeric'
        unless self.value.to_f >= 0
          errors.add(:value, 'must be greater than or equal to zero.  Please enter another value.')
        end
      else
        # for booleans, we use a select box so values are constrained.  for strings, any value is valid
        return true
    end
  end
end

