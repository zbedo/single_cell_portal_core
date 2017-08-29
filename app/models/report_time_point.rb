class ReportTimePoint

  ###
  #
  # ReportTimePoint: generic container for storing time-based reporting data (for ReportsController graphs)
  #
  ###

  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :date, type: Date
  field :value, type: Hash

  validates_presence_of :name, :date, :value

  ## Custom Reporting Methods

  # get a weekly count of users that have logged into the portal
  def self.weekly_returning_users
    today = Date.today
    one_week_ago = today - 1.weeks
    user_count = User.all.select {|user| (user.last_sign_in_at >= one_week_ago || user.current_sign_in_at >= one_week_ago) && (user.last_sign_in_at < today || user.current_sign_in_at < today) }.size
    self.create!(name: 'Weekly Returning Users', date: today, value: {count: user_count, description: "Count of returning users from #{one_week_ago} to #{today}"})
  end
end
