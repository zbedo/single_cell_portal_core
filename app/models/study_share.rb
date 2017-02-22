class StudyShare
	include Mongoid::Document
	include Mongoid::Timestamps

	belongs_to :study

	field :email, type: String
	field :permission, type: String, default: 'View'

	validates_uniqueness_of :email, scope: :study_id

	PERMISSION_TYPES = %w(Edit View)

	before_save :clean_email
	after_create :send_notification
	after_update :check_updated_permissions

	private

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
end