##
#
# UploadCleanupJob - a scheduled job that will verify that a study_file has successfully been uploaded to GCS and will then
# remove the local copy of the file
#
##

class UploadCleanupJob < Struct.new(:study, :study_file, :retry_count)
  extend ErrorTracker

  def perform
    retries = retry_count + 1
    # make sure file or study isn't queued for deletion first
    if study_file.nil?
      Rails.logger.info "#{Time.zone.now}: aborting UploadCleanupJob due to StudyFile already being deleted."
    elsif study_file.queued_for_deletion || study.queued_for_deletion
      Rails.logger.info "#{Time.zone.now}: aborting UploadCleanupJob for #{study_file.bucket_location}:#{study_file.id} in '#{study.name}', file queued for deletion"
      # check if there's still a local copy we need to clean up
      if study_file.is_local?
        study_file.remove_local_copy
      end
    else
      if !study_file.is_local?
        Rails.logger.error "#{Time.zone.now}: error in UploadCleanupJob for #{study.name}:#{study_file.bucket_location}:#{study_file.id}; file no longer present"
        SingleCellMailer.admin_notification('File missing on cleanup', nil, "<p>The study file #{study_file.upload_file_name} was missing from the local file system at the time of cleanup job execution.  Please check #{study.firecloud_project}/#{study.firecloud_workspace} to ensure the upload occurred.</p>")
      else
        begin
          # check workspace bucket for existence of remote file
          Rails.logger.info "#{Time.zone.now}: performing UploadCleanupJob for #{study_file.bucket_location}:#{study_file.id} in '#{study.name}'"
          remote_file = Study.firecloud_client.execute_gcloud_method(:get_workspace_file, 0, study.firecloud_project,
                                                                     study.firecloud_workspace, study_file.bucket_location)
          if remote_file.present?
            # check generation tags to make sure we're in sync
            Rails.logger.info "#{Time.zone.now}: remote file located for #{study_file.bucket_location}:#{study_file.id}, checking generation tag"
            if remote_file.generation.to_s == study_file.generation
              Rails.logger.info "#{Time.zone.now}: generation tags for #{study_file.bucket_location}:#{study_file.id} match, performing cleanup"
            else
              Rails.logger.info "#{Time.zone.now}: generation tags for #{study_file.bucket_location}:#{study_file.id} do not match, updating database records"
              study_file.update(generation: remote_file.generation)
              Rails.logger.info "#{Time.zone.now}: generation tag for #{study_file.bucket_location}:#{study_file.id} updated, performing cleanup"
            end
            # once everything is in sync, perform cleanup
            study_file.remove_local_copy
            Rails.logger.info "#{Time.zone.now}: cleanup for #{study_file.bucket_location}:#{study_file.id} complete"
          else
            # remote file was not found, so attempt upload again and reschedule cleanup
            Rails.logger.info "#{Time.zone.now}: remote file MISSING for #{study_file.bucket_location}:#{study_file.id}, attempting upload"
            study.send_to_firecloud(study_file)
            # schedule a new cleanup job
            interval = retries * 2
            run_at = interval.minutes.from_now
            Rails.logger.info "#{Time.zone.now}: scheduling new UploadCleanupJob for #{study_file.bucket_location}:#{study_file.id}, will run at #{run_at}"
            Delayed::Job.enqueue(UploadCleanupJob.new(study, study_file, retries), run_at: run_at)
          end
        rescue => e
          error_context = ErrorTracker.format_extra_context(study, study_file, {retry_count: retry_count})
          ErrorTracker.report_exception(e, nil, error_context)
          if retries <= 3
            interval = retries * 2
            run_at = interval.minutes.from_now
            Rails.logger.error "#{Time.zone.now}: error in UploadCleanupJob for #{study.name}:#{study_file.bucket_location}:#{study_file.id}, will retry at #{run_at}; #{e.message}"
            Delayed::Job.enqueue(UploadCleanupJob.new(study, study_file, retries), run_at: run_at)
          else
            Rails.logger.error "#{Time.zone.now}: error in UploadCleanupJob for #{study.name}:#{study_file.bucket_location}:#{study_file.id}; #{e.message}"
            SingleCellMailer.admin_notification('UploadCleanupJob failure', nil, "<p>The following failure occurred when attempting to upload/clean up #{study.firecloud_project}/#{study.firecloud_workspace}:#{study_file.bucket_location}: #{e.message}</p>").deliver_now
          end
        end
      end
    end
  end
end