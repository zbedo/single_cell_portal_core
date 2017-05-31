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

  # method that disables all downloads by revoking permissions to studies directly in firecloud
  def self.disable_all_downloads
    Rails.logger.info "#{Time.now}: revoking access to all studies"
    # only use studies not queued for deletion; those have already had access revoked
    Study.not_in(queued_for_deletion: true).each do |study|
      Rails.logger.info "#{Time.now}: begin revoking access to study: #{study.name}"
      # first remove share access
      shares = study.study_shares.map(&:email)
      shares.each do |user|
        Rails.logger.info "#{Time.now}: revoking share access for #{user}"
        revoke_share_acl = Study.firecloud_client.create_workspace_acl(user, 'NO ACCESS')
        Study.firecloud_client.update_workspace_acl(study.firecloud_workspace, revoke_share_acl)
      end
      # last, remove study owner access
      owner = study.user.email
      Rails.logger.info "#{Time.now}: revoking owner access for #{owner}"
      revoke_owner_acl = Study.firecloud_client.create_workspace_acl(owner, 'NO ACCESS')
      Study.firecloud_client.update_workspace_acl(study.firecloud_workspace, revoke_owner_acl)
      Rails.logger.info "#{Time.now}: access revocation for #{study.name} complete"
    end
    Rails.logger.info "#{Time.now}: all study access revoked"
  end

  # method that enables all downloads by restoring permissions to studies directly in firecloud
  def self.enable_all_downloads
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
