class UserAnnotationShare
	include Mongoid::Document
	include Mongoid::Timestamps

	belongs_to :user_annotation
  belongs_to :study

	field :email, type: String
	field :permission, type: String, default: 'View'

	validates_uniqueness_of :email, scope: :user_annotation_id

	index({ email: 1, user_annotation_id: 1 }, { unique: true })

	PERMISSION_TYPES = %w(Edit View)

	before_save					:clean_email
	after_create				:send_notification
	after_update				:check_updated_permissions

	private
  def clean_email
		self.email = self.email.strip
	end

	# send an email to both annotation owner & share user notifying them of the share
	def send_notification
		SingleCellMailer.share_annotation_notification(self.user_annotation.user, self).deliver_now
	end

	# send an email to both study owner & share user notifying them of the share
	def check_updated_permissions
		if self.permission_changed?
			SingleCellMailer.share_annotation_notification(self.user_annotation.user, self).deliver_now
		end
	end
end