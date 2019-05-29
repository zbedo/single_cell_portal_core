class DeploymentNotification
  include Mongoid::Document
  field :deployment_time, type: DateTime
  field :message, type: String
  validates_presence_of :deployment_time
  validate :deployment_date_cannot_be_in_past
  validate :validate_single_record

  def display_time
    (self.deployment_time - 4.hours)
  end

  private
  def deployment_date_cannot_be_in_past
    errors.add(:deployment_time, "cannot be before today.") unless Time.zone.now.prev_day < deployment_time
  end

  def validate_single_record
    errors.add('There can only be one deployment scheduled at a time') unless  DeploymentNotification.find.nil?
  end
end
