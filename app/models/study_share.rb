class StudyShare
	include Mongoid::Document
	include Mongoid::Timestamps

	belongs_to :study

	field :email, type: String
	field	:firecloud_workspace, type: String
	field :permission, type: String, default: 'View'

	validates_uniqueness_of :email, scope: :study_id

	PERMISSION_TYPES = %w(Edit View)
	FIRECLOUD_ACLS = %w(WRITER READER)
	FIRECLOUD_ACL_MAP = Hash[PERMISSION_TYPES.zip(FIRECLOUD_ACLS)]

	before_validation		:set_firecloud_workspace
	before_save					:clean_email
	after_create				:send_notification
	after_update				:check_updated_permissions
	validate						:set_firecloud_acl, on: [:create, :update]
	validate						:revoke_firecloud_acl, on: :destroy

	# method to set firecloud_workspace in all existing shares (without firing callbacks)
	def self.set_all_firecloud_workspaces
		self.skip_callback(:save, :after, :set_firecloud_acl)
		self.all.each do |share|
			share.update(firecloud_workspace: share.study.firecloud_workspace)
		end
		self.set_callback(:save, :after, :set_firecloud_acl)
	end

	private

	def set_firecloud_workspace
		self.firecloud_workspace = self.study.firecloud_workspace
	end

	def clean_email
		self.email.strip!
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
		end
		Rails.logger.info "#{Time.now}: Creating FireCloud ACLs for study #{self.study.name}"
		begin
			acl = Study.firecloud_client.create_acl(self.email, FIRECLOUD_ACL_MAP[self.permission])
			Study.firecloud_client.update_workspace_acl(self.study.firecloud_workspace, acl)
		rescue RuntimeError => e
			errors.add(:base, "Could not create a share for #{self.email} to workspace #{self.firecloud_workspace} due to: #{e.message}")
			false
		end
	end

	# revoke FireCloud workspace access on share deletion, raise validation error on fail and halt execution
	def revoke_firecloud_acl
		begin
			acl = Study.firecloud_client.create_acl(self.email, 'NO ACCESS')
			Study.firecloud_client.update_workspace_acl(self.firecloud_workspace, acl)
		rescue RuntimeError => e
			errors.add(:base, "Could not remove share for #{self.email} to workspace #{self.firecloud_workspace} due to: #{e.message}")
			false
		end
	end
end