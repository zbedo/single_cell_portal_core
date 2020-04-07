require "test_helper"

class SummaryStatsUtilsTest < ActiveSupport::TestCase

  def setup
    @now = DateTime.now
    @today = Time.zone.today
    @one_week_ago = @today - 1.week
    @one_month_ago = @today - 1.month
    @random_seed = File.open(Rails.root.join('.random_seed')).read.strip
  end

  test 'should get user counts' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    # manually update all user's current_sign_in_at to mimic sign_in
    User.update_all(current_sign_in_at: @now)
    expected_user_count = User.count
    user_stats = SummaryStatsUtils.daily_total_and_active_user_counts
    assert_equal [:total, :active], user_stats.keys
    assert_equal expected_user_count, user_stats[:total]
    assert_equal expected_user_count, user_stats[:active]

    # exercise cutoff date
    user_stats = SummaryStatsUtils.daily_total_and_active_user_counts(end_date: @one_week_ago)
    assert_equal 0, user_stats[:total]
    assert_equal 0, user_stats[:active]

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test 'should get analysis submission counts' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    # manually insert a submission to check
    AnalysisSubmission.create!(submitter: User.first.email, submission_id: SecureRandom.uuid, analysis_name: 'test-analysis',
                               submitted_on: @now, firecloud_project: FireCloudClient::PORTAL_NAMESPACE,
                               firecloud_workspace: 'test-workspace')
    submission_count = SummaryStatsUtils.analysis_submission_count
    assert_equal 1, submission_count

    # exercise cutoff date
    submission_count = SummaryStatsUtils.analysis_submission_count(start_date: @one_month_ago, end_date: @one_week_ago)
    assert_equal 0, submission_count

    # clean up
    AnalysisSubmission.destroy_all

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test 'should get study creation counts' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    expected_study_count = Study.count
    studies_created = SummaryStatsUtils.daily_study_creation_count
    assert_equal expected_study_count, studies_created

    # exercise cutoff date
    studies_created = SummaryStatsUtils.daily_study_creation_count(end_date: @one_week_ago)
    assert_equal 0, studies_created

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test 'should verify all remote files' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    # from db/seeds.rb, we should have at least one missing file from the DirectoryListing called "csvs"
    # there is a file called 'foo.csv' that is never created or uploaded to the bucket
    # this DirectoryListing belongs to the API Test Study from db/seeds.rb
    api_study = Study.find_by(name: "API Test Study #{@random_seed}")
    files_missing = SummaryStatsUtils.storage_sanity_check
    missing_csv = files_missing.detect {|entry| entry[:filename] == 'foo.csv'}
    reason = "File missing from bucket: #{api_study.bucket_id}"
    assert missing_csv.present?, "Did not find expected missing file of 'foo.csv'"
    assert missing_csv[:study] == api_study.name
    assert missing_csv[:owner] == api_study.user.email
    assert missing_csv[:reason] == reason

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test 'should get disk usage stats' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    disk_usage_keys = [:total_space, :space_used, :space_free, :percent_used, :mount_point]
    disk_usage = SummaryStatsUtils.disk_usage
    assert_equal disk_usage_keys, disk_usage.keys
    disk_usage.each do |key, value|
      assert_not_nil value, "Did not find a value for #{key}: #{value}"
    end

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test 'should get ingest run counts' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    # testing the count of submissions is never going to be idempotent as it depends entirely on the number
    # of PRs and builds that have run in any given time frame
    # likely all we can do is prove that we get a number greater than 0, and then use a future cutoff date that should
    # return 0 as no runs have been initiated then yet
    ingest_runs = SummaryStatsUtils.ingest_run_count
    assert ingest_runs > 0, "Should have found at least one ingest run for today, instead found: #{ingest_runs}"
    tomorrow = @today + 1.day
    runs_tomorrow = SummaryStatsUtils.ingest_run_count(start_date: tomorrow, end_date: tomorrow + 1.day)
    assert_equal 0, runs_tomorrow, "Should not have found any ingest runs for tomorrow: #{runs_tomorrow}"

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

end
