##
# PortalUtils: generic class with server stats/maintenance methods
##
class PortalUtils

  # nightly report to send to portal admins with stats about the current usage of the portal
  def self.nightly_server_report
    # get user, submission, and study stats
    today = Date.today
    two_weeks_ago = today - 2.weeks
    @total_users = User.count
    @active_users = User.where(:current_sign_in_at.gte => today).count
    @submissions = AnalysisSubmission.where(:submitted_on.gte => two_weeks_ago, submitted_from_portal: true).count
    @studies_created = Study.where(:created_at.gte => today)

    # find out all ingest jobs run today; since the "filter" parameter for list_project_operations doesn't work,
    # check dates manually.
    @ingest_jobs = 0
    jobs = ApplicationController.papi_client.list_pipelines
    all_today_listed = false
    while !all_today_listed
      jobs.operations.each do |job|
        submission_date = Date.parse(job.metadata['startTime'])
        if submission_date == today
          @ingest_jobs += 1
        else
          all_today_listed = true
          break
        end
      end
      jobs = ApplicationController.papi_client.list_pipelines(page_token: jobs.next_page_token)
    end

    # disk usage
    header, portal_disk = `df -h /home/app/webapp`.split("\n")
    table_header = header.split
    details = portal_disk.split
    table_header.slice!(-1)
    @disk_usage = {headers: table_header, details: details}

    # storage sanity check
    @missing_files = self.storage_sanity_check
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
end
