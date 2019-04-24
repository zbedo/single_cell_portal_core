class AnalysisSubmission
  include Mongoid::Document
  field :submission_id, type: String
  field :submitter, type: String
  field :analysis_name, type: String
  field :status, type: String
  field :firecloud_project, type: String
  field :firecloud_workspace, type: String
  field :submitted_on, type: DateTime
  field :completed_on, type: DateTime
  field :submitted_from_portal, type: Boolean, default: true

  belongs_to :study, optional: true

  SUBMISSON_STATUSES = %w(Queued Launching Submitted Running Failed Succeeded Aborting Aborted Unknown).freeze
  COMPLETION_STATUSES = %w(Aborted Succeeded Failed)
  validates_presence_of :submission_id, :submitter, :analysis_name, :firecloud_project, :firecloud_workspace
  validates_inclusion_of :status, in: SUBMISSON_STATUSES, if: proc {|attributes| attributes.status.present?}
  validates_uniqueness_of :submission_id

  # initialize a new AnalysisSubmission record from the FireCloud API JSON entry
  # only to be used to backfill existing submissions
  def self.initialize_from_submission(study, submission_id)
    analysis_submission = AnalysisSubmission.new(study_id: study.id, firecloud_project: study.firecloud_project,
                                                 firecloud_workspace: study.firecloud_workspace, submission_id: submission_id)
    submission = analysis_submission.get_submission_json
    analysis_submission.submitter = submission['submitter']
    analysis_submission.submission_id = submission['submissionId']
    last_workflow = submission['workflows'].last
    analysis_submission.status = last_workflow['status']
    analysis_submission.submitted_on = DateTime.parse(submission['submissionDate']).in_time_zone
    analysis_method_name = analysis_submission.get_analysis_name_from_config(submission)
    analysis_submission.analysis_name = analysis_method_name
    if COMPLETION_STATUSES.include?(analysis_submission.status)
      completion_time = DateTime.parse(last_workflow['statusLastChangedDate']).in_time_zone
      analysis_submission.completed_on = completion_time
    end
    analysis_submission.save
  end

  # get user instance for submitter
  def user
    User.find_by(email: self.submitter)
  end

  # helper to get submission JSON from workspace
  def get_submission_json
    begin
      Study.firecloud_client.get_workspace_submission(self.firecloud_project, self.firecloud_workspace, self.submission_id)
    rescue => e
      error_context = ErrorTracker.format_extra_context(self)
      ErrorTracker.report_exception(e, self.user, error_context)
      logger.error "Unable to retrieve submission JSON for #{self.firecloud_project}/#{self.firecloud_workspace}:#{self.submission_id}; #{e.message}"
    end
  end

  # get the analysis name from the configuration used to submit this analysis
  def get_analysis_name_from_config(submission)
    begin
      configuration_namespace = submission['methodConfigurationNamespace']
      configuration_name = submission['methodConfigurationName']
      configuration = Study.firecloud_client.get_workspace_configuration(self.firecloud_project, self.firecloud_workspace,
                                                                  configuration_namespace, configuration_name)
      method = configuration['methodRepoMethod']
      "#{method['methodNamespace']}/#{method['methodName']}/#{method['methodVersion']}"
    rescue => e
      error_context = ErrorTracker.format_extra_context(self)
      ErrorTracker.report_exception(e, self.user, error_context)
      logger.error "Unable to retrieve submission configuration JSON for #{self.firecloud_project}/#{self.firecloud_workspace}:#{self.submission_id}; #{e.message}"
    end
  end

  # set the completion date based on current status
  def set_completed_on
    if COMPLETION_STATUSES.include?(self.status) && self.completed_on.blank?
      submission = self.get_submission_json
      last_workflow = submission['workflows'].last
      if submission.present?
        completion_time = DateTime.parse(last_workflow['statusLastChangedDate']).in_time_zone
        self.update(completed_on: completion_time)
      end
    end
  end
end
