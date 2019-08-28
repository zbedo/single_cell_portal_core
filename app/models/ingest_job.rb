##
# IngestJob: lightweight wrapper around a PAPI ingest job with mappings to the study/file/user associated
# with this particular ingest job.  Handles polling for completion and notifying the user
##

class IngestJob
  include ActiveModel::Model
  attr_accessor :pipeline_name, :study, :study_file, :user

  validates_presence_of :pipeline_name, :study, :study_file, :user

  # Patch for using with Delayed::Job.  Returns true to mimic an ActiveRecord instance
  #
  # * *returns*
  #   - True::TrueClass
  def persisted?
    true
  end

  # Return an updated reference to this ingest run in PAPI
  #
  # * *returns*
  #   - (Google::Apis::GenomicsV2alpha1::Operation)
  def get_ingest_run
    ApplicationController.papi_client.get_pipeline(name: self.pipeline_name)
  end

  # Determine if this ingest run has done by checking current status
  #
  # * *returns*
  #   - (Boolean) => Indication of whether or not job has completed
  def done?
    self.get_ingest_run.done?
  end

  # Get all errors for ingest job
  #
  # * *returns*
  #   - (Google::Apis::GenomicsV2alpha1::Status)
  def error
    self.get_ingest_run.error
  end

  # Determine if a job failed by checking for errors
  #
  # * *returns*
  #   - (Boolean) => Indication of whether or not job failed via an unrecoverable error
  def failed?
    self.error.present?
  end

  # Get a status label for current state of job
  #
  # * *returns*
  #   - (String) => Status label
  def current_status
    if self.done?
      self.failed? ? 'Error' : 'Completed'
    else
      'Running'
    end
  end

  # Get the PAPI job metadata
  #
  # * *returns*
  #   - (Hash) => Metadata of PAPI job, including events, environment, labels, etc.
  def metadata
    self.get_ingest_run.metadata
  end

  # Get all the events for a given ingest job in chronological order
  #
  # * *returns*
  #   - (Array<Google::Apis::GenomicsV2alpha1::Event>) => Array of pipeline events, sorted by timestamp
  def events
    self.metadata['events'].sort_by! {|event| event['timestamp'] }
  end

  # Get all messages from all events
  #
  # * *returns*
  #   - (Array<String>) => Array of all messages in chronological order
  def event_messages
    self.events.map {|event| event['description']}
  end

  # Get the total runtime of parsing from event timestamps
  #
  # * *returns*
  #   - (String) => Text representation of total elapsed time
  def get_total_runtime
    events = self.events
    start_time = DateTime.parse(events.first['timestamp'])
    completion_time = DateTime.parse(events.last['timestamp'])
    TimeDifference.between(start_time, completion_time).humanize
  end

  # Launch a background polling process.  Will check for completion, and if the pipeline has not completed
  # running, it will enqueue a new poller and exit to free up resources.  Defaults to checking every minute.
  # Job does not return anything, but will handle success/failure accordingly.
  #
  # * *params*
  #   - +run_at+ (DateTime) => Time at which to run new polling check
  def poll_for_completion(run_at: 30.seconds.from_now)
    if self.done? && !self.failed?
      Rails.logger.info "IngestJob poller: #{self.pipeline_name} is done!"
      Rails.logger.info "IngestJob poller: #{self.pipeline_name} status: #{self.current_status}"
      self.study_file.update(parse_status: 'parsed')
      subject = "#{self.study_file.file_type} file: '#{self.study_file.upload_file_name}' has completed parsing"
      message = ["Total parse time: #{self.get_total_runtime}"]
      SingleCellMailer.notify_user_parse_complete(self.user.email, subject, message).deliver_now
      self.set_study_state_after_ingest
    elsif self.done? && self.failed?
      Rails.logger.error "IngestJob poller: #{self.pipeline_name} has failed."
      DeleteQueueJob.new(self.study_file).delay.perform
      Study.firecloud_client.delete_workspace_file(self.study.bucket_id, self.study_file.bucket_location)
      subject = "Error: #{self.study_file.file_type} file: '#{self.study_file.upload_file_name}' parse has failed"
      messages = self.event_messages
      SingleCellMailer.notify_user_parse_fail(self.user.email, subject, "<p>#{messages.join('<br />')}</p>").deliver_now
    else
      Rails.logger.info "IngestJob poller: #{self.pipeline_name} is not done; queuing check for #{run_at}"
      self.delay(run_at: run_at).poll_for_completion
    end
  end

  # Set study state depending on what kind of file was just ingested
  def set_study_state_after_ingest
    case self.study_file.file_type
    when 'Metadata'
      self.study.set_cell_count
      self.set_study_default_options
    when 'Expression Matrix'
      self.study.set_gene_count
    when 'MM Coordinate Matrix'
      self.study.set_gene_count
    when 'Cluster'
      self.set_study_default_options
    end
  end

  # Set the default options for a study after ingesting Clusters/Cell Metadata
  def set_study_default_options
    case self.study_file.file_type
    when 'Metadata'
      if self.study.default_options[:annotation].nil?
        cell_metadatum = FirestoreCellMetadatum.by_study(self.study.accession).first
        self.study.default_options[:annotation] = cell_metadatum.annotation_select_value
        if cell_metadatum.annotation_type == 'numeric'
          self.study.default_options[:color_profile] = 'Reds'
        end
      end
    when 'Cluster'
      if self.study.default_options[:cluster].nil?
        cluster = FirestoreCluster.by_study_and_name(self.study.accession, self.study_file.name)
        self.study.default_options[:cluster] = cluster.name
        if self.study.default_annotation.nil? && cluster.cell_annotations.any?
          annotation = cluster.cell_annotations.first
          self.study.default_options[:annotation] = cluster.annotation_select_value(annotation)
          if annotation[:type] == 'numeric'
            self.study.default_options[:color_profile] = 'Reds'
          end
        end
      end
    end
    Rails.logger.info "Setting default options in #{self.study.name}: #{self.study.default_options}"
    self.study.save
  end
end
