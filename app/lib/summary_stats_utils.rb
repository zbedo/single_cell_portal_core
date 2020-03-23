##
# PortalUtils: generic class with server stats/maintenance methods
#
# note: all instances of :start_date and :end_date are inclusive
##
class SummaryStatsUtils

  # get a snapshot of user counts/activity up to a given date
  # will give count of users as of that date, and number of active users on that date
  def self.total_and_active_user_counts(end_date: Time.zone.today)
    # make sure to make end_date one day forward to include any users that were created on cutoff date
    next_day = end_date + 1.day
    total_users = User.where(:created_at.lte => next_day).count
    active_users = User.where(:current_sign_in_at => (end_date..next_day)).count
    {total: total_users, active: active_users}
  end

  # get a count of all submissions launch from the portal in a given 2 week period
  # defaults to a time period of the last two weeks from right now
  def self.analysis_submission_count(start_date: DateTime.now - 2.weeks, end_date: DateTime.now)
    AnalysisSubmission.where(:submitted_on => (start_date..end_date), submitted_from_portal: true).count
  end

  # get a count of all studies created on the requested day
  def self.study_creation_count(end_date: Time.zone.today)
    Study.where(:created_at => (end_date..(end_date + 1.day))).count
  end

  # perform a sanity check to look for any missing files in remote storage
  # returns a list of all missing files for entire portal for use in nightly_server_report
  def self.storage_sanity_check
    missing_files = []
    Study.where(queued_for_deletion: false, detached: false).each do |study|
      begin
        study_missing = study.verify_all_remotes
        study_missing.any? ? missing_files += study_missing : nil
      rescue => e
        # check if the bucket or the workspace is missing and mark study accordingly
        study.set_study_detached_state(e)
        ErrorTracker.report_exception(e, nil, {})
        Rails.logger.error  "Error in retrieving remotes for #{study.name}: #{e.message}"
        missing_files << {filename: 'N/A', study: study.name, owner: study.user.email, reason: "Error retrieving remotes: #{e.message}"}
      end
    end
    missing_files
  end

  # disk usage stats
  def self.disk_usage
    stat = Filesystem.stat(Rails.root.to_s)
    {
        total_space: stat.bytes_total,
        space_used: stat.bytes_used,
        space_free: stat.bytes_free,
        percent_used: (100 * (stat.bytes_used / stat.bytes_total.to_f)).round,
        mount_point: stat.path
    }
  end

  # find out all ingest jobs run in a given time period
  # since the "filter" parameter for list_project_operations doesn't work, check dates manually.
  # defaults to current day
  def self.ingest_run_count(start_date: Time.zone.today, end_date: Time.zone.today + 1.day)
    ingest_jobs = 0
    jobs = ApplicationController.papi_client.list_pipelines
    all_from_range = false
    until all_from_range
      jobs.operations.each do |job|
        submission_date = Date.parse(job.metadata['startTime'])
        if submission_date >= start_date && submission_date <= end_date
          ingest_jobs += 1
        else
          all_from_range = true
          break
        end
      end
      jobs = ApplicationController.papi_client.list_pipelines(page_token: jobs.next_page_token) if !all_from_range
    end
    ingest_jobs
  end
end
