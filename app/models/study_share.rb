class StudyShare

  ###
  #
  # StudyShare: class to hold sharing information about studies.  Integrates with FireCloud workspace ACLs.
  #
  ###

  ###
  #
  # FIELD DEFINITIONS, VALIDATIONS & CALLBACKS
  #
  ###

	include Mongoid::Document
	include Mongoid::Timestamps

	belongs_to :study

	field :email, type: String
	field	:firecloud_workspace, type: String
	field :permission, type: String, default: 'View'

	validates_uniqueness_of :email, scope: :study_id

	index({ email: 1, study_id: 1 }, { unique: true })

	PERMISSION_TYPES = %w(Owner Edit View)
	FIRECLOUD_ACLS = %w(OWNER WRITER READER)

	# hashes that represent ACL mapping between the portal & firecloud and the inverse
	FIRECLOUD_ACL_MAP = Hash[PERMISSION_TYPES.zip(FIRECLOUD_ACLS)]
	PORTAL_ACL_MAP = Hash[FIRECLOUD_ACLS.zip(PERMISSION_TYPES)]

	before_validation		:set_firecloud_workspace, on: :create
	before_save					:clean_email
	after_create				:send_notification
	after_update				:check_updated_permissions
	validate						:set_firecloud_acl, on: [:create, :update]
	before_destroy			:revoke_firecloud_acl

	private

  ###
  #
  # SETTERS & CUSTOM VALIDATIONS/CALLBACKS
  #
  ###

	def set_firecloud_workspace
		self.firecloud_workspace = self.study.firecloud_workspace
	end

	def clean_email
		self.email = self.email.strip
	end

	# send an email to both study owner & share user notifying them of the share
	def send_notification
		SingleCellMailer.share_notification(self.study.user, self).deliver_now
	end

	# send an email to both study owner & share user notifying them of the share
	def check_updated_permissions
		if self.permission_changed?
			SingleCellMailer.share_notification(self.study.user, self).deliver_now
		end
	end

	# set FireCloud workspace ACLs on share saving, raise validation error on fail and halt execution
	def set_firecloud_acl
		# in case of new study creation, automatically return true as we will create shares after study workspace is created
		if self.new_record? && self.study.new_record?
			return true
		else
			# set acls only if a new share or if the permission has changed
			if (self.new_record? && !self.study.new_record?) || (!self.new_record? && self.permission_changed?)
				Rails.logger.info "#{Time.now}: Creating FireCloud ACLs for study #{self.study.name} - share #{self.email}, permission: #{self.permission}"
				begin
					acl = Study.firecloud_client.create_workspace_acl(self.email, FIRECLOUD_ACL_MAP[self.permission])
					Study.firecloud_client.update_workspace_acl(self.study.firecloud_workspace, acl)
				rescue RuntimeError => e
					errors.add(:base, "Could not create a share for #{self.email} to workspace #{self.firecloud_workspace} due to: #{e.message}")
					false
				end
			end
		end
	end

	# revoke FireCloud workspace access on share deletion, will email owner on fail to manually remove sharing as we can't do a validation on destroy
	def revoke_firecloud_acl
		begin
			acl = Study.firecloud_client.create_workspace_acl(self.email, 'NO ACCESS')
			Study.firecloud_client.update_workspace_acl(self.firecloud_workspace, acl)
		rescue RuntimeError => e
			Rails.logger.error "#{Time.now}: Could not remove share for #{self.email} to workspace #{self.firecloud_workspace} due to: #{e.message}"
			SingleCellMailer.share_delete_fail(self.study, self.email).deliver_now
		end
	end
end