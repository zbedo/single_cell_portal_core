##
#
# UploadCleanupJob - a scheduled job that will verify that a study_file has successfully been uploaded to GCS and will then
# remove the local copy of the file
#
##

class UploadCleanupJob < Struct.new(:study, :study_file)

  def perform
    file_location = study_file.upload.path
    # make sure the local file still exists
    if !File.exists?(file_location)
      Rails.logger.error "#{Time.now}: error in UploadCleanupJob for #{study.name}:#{study_file.upload_file_name}; file no longer present"
      SingleCellMailer.admin_notification('File missing on cleanup', nil, "<p>The study file #{study_file.upload.path} was missing from the local file system at the time of cleanup job execution.  Please check #{study.firecloud_workspace} to ensure the upload occurred.</p>")
    else
      begin
        # check workspace bucket for existence of remote file
        Rails.logger.info "#{Time.now}: performing UploadCleanupJob for #{study_file.upload_file_name} in '#{study.name}'"
        remote_file = Study.firecloud_client.execute_gcloud_method(:get_workspace_file, study.firecloud_workspace, study_file.upload_file_name)
        if remote_file.present?
          # check generation tags to make sure we're in sync
          Rails.logger.info "#{Time.now}: remote file located for #{study_file.upload_file_name}, checking generation tag"
          if remote_file.generation == study_file.generation
            Rails.logger.info "#{Time.now}: generation tags for #{study_file.upload_file_name} match, performing cleanup"
          else
            Rails.logger.info "#{Time.now}: generation tags for #{study_file.upload_file_name} do not match, updating database records"
            study_file.update(generation: remote_file.generation)
            Rails.logger.info "#{Time.now}: generation tag for #{study_file.upload_file_name} updated, performing cleanup"
          end
          # once everything is in sync, perform cleanup
          File.delete(study_file.upload.path)
          Rails.logger.info "#{Time.now}: cleanup for #{study_file.upload_file_name} complete"
        else
          # remote file was not found, so attempt upload again and reschedule cleanup
          Rails.logger.info "#{Time.now}: remote file MISSING for #{study_file.upload_file_name}, attempting upload"
          study.send_to_firecloud(study_file)
          # schedule a new cleanup job
          run_at = 2.minutes.from_now
          Rails.logger.info "#{Time.now}: scheduling new UploadCleanupJob for #{study_file.upload_file_name}, will run at #{run_at}"
          Delayed::Job.enqueue(UploadCleanupJob.new(study, study_file), run_at: run_at)
        end
      rescue => e
        Rails.logger.error "#{Time.now}: error in UploadCleanupJob for #{study.name}:#{study_file.upload_file_name}; #{e.message}"
        SingleCellMailer.admin_notification('UploadCleanupJob failure', nil, "<p>The following failure occurred when attempting to clean up #{study_file.upload.path}: #{e.message}</p>")
      end
    end
  end
end