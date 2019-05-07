module Api
  module V1
    class SiteController < ApiBaseController
      include Concerns::Authenticator
      include Swagger::Blocks

      before_action :set_current_api_user!
      before_action :set_study, except: [:studies, :analyses, :get_analysis]
      before_action :set_analysis_configuration, only: [:get_analysis, :get_study_analysis_config]
      before_action :check_study_view_permission, except: [:studies, :analyses, :get_analysis]
      before_action :check_study_compute_permission,
                    only: [:get_study_analysis_config, :submit_study_analysis, :get_study_submissions,
                           :get_study_submission, :sync_submission_outputs]
      before_action :check_study_edit_permission, only: [:sync_submission_outputs]
      before_action :set_study_file, only: [:download_data, :stream_data]
      before_action :get_download_quota, only: [:download_data, :stream_data]

      swagger_path '/site/studies' do
        operation :get do
          key :tags, [
              'Site'
          ]
          key :summary, 'Find all Studies viewable to user'
          key :description, 'Returns all Studies viewable by the current user, including public studies'
          key :operationId, 'site_studies_path'
          response 200 do
            key :description, 'Array of Study objects'
            schema do
              key :type, :array
              key :title, 'Array'
              items do
                key :title, 'Study'
                key :'$ref', :SiteStudy
              end
            end
          end
          response 406 do
            key :description, 'Accept or Content-Type headers missing or misconfigured'
          end
        end
      end

      def studies
        if api_user_signed_in?
          @studies = Study.viewable(current_api_user, {api_request: true})
        else
          @studies = Study.where(public: true)
        end
      end

      swagger_path '/site/studies/{accession}' do
        operation :get do
          key :tags, [
              'Site'
          ]
          key :summary, 'View a Study & available StudyFiles'
          key :description, 'View a single Study, and any StudyFiles available for download/streaming'
          key :operationId, 'site_study_view_path'
          parameter do
            key :name, :accession
            key :in, :path
            key :description, 'Accession of Study to fetch'
            key :required, true
            key :type, :string
          end
          response 200 do
            key :description, 'Study, Array of StudyFiles'
            schema do
              key :title, 'Study, StudyFiles'
              key :'$ref', :SiteStudyWithFiles
            end
          end
          response 403 do
            key :description, 'User is not allowed to view study'
          end
          response 404 do
            key :description, 'Study not found'
          end
          response 406 do
            key :description, 'Accept or Content-Type headers missing or misconfigured'
          end
        end
      end

      def view_study

      end

      swagger_path '/site/studies/{accession}/download' do
        operation :get do
          key :tags, [
              'Site'
          ]
          key :summary, 'Download a StudyFile'
          key :description, 'Download a single StudyFile (via signed URL)'
          key :operationId, 'site_study_download_data_path'
          parameter do
            key :name, :accession
            key :in, :path
            key :description, 'Accession of Study to fetch'
            key :required, true
            key :type, :string
          end
          parameter do
            key :name, :filename
            key :in, :query
            key :description, 'Name/location of file to download'
            key :required, true
            key :type, :string
          end
          response 200 do
            key :description, 'File object'
            key :type, :file
          end
          response 403 do
            key :description, 'User is not allowed to view study'
          end
          response 404 do
            key :description, 'Study or StudyFile not found'
          end
          response 406 do
            key :description, 'Accept or Content-Type headers missing or misconfigured'
          end
        end
      end

      def download_data
        begin
          if @study_file.present?
            filesize = @study_file.upload_file_size
            user_quota = current_api_user.daily_download_quota + filesize
            # check against download quota that is loaded in ApplicationController.get_download_quota
            if user_quota <= @download_quota
              @signed_url = Study.firecloud_client.execute_gcloud_method(:generate_signed_url, 0, @study.firecloud_project,
                                                                         @study.firecloud_workspace, @study_file.bucket_location,
                                                                         expires: 15)
              current_api_user.update(daily_download_quota: user_quota)
              redirect_to @signed_url
            else
              alert = 'You have exceeded your current daily download quota.  You must wait until tomorrow to download this file.'
              render json: {error: alert}, status: 403
            end
          else
            render json: {error: "File not found: #{params[:filename]}"}, status: 404
          end
        rescue RuntimeError => e
          error_context = ErrorTracker.format_extra_context(@study, {params: params})
          ErrorTracker.report_exception(e, current_api_user, error_context)
          logger.error "Error generating signed url for #{params[:filename]}; #{e.message}"
          render json: {error: "Error generating signed url for #{params[:filename]}; #{e.message}"}, status: 500
        end
      end

      swagger_path '/site/studies/{accession}/stream' do
        operation :get do
          key :tags, [
              'Site'
          ]
          key :summary, 'Stream a StudyFile'
          key :description, 'Retrieve media URL for a StudyFile to stream to a client'
          key :operationId, 'site_study_stream_data_path'
          parameter do
            key :name, :accession
            key :in, :path
            key :description, 'Accession of Study to fetch'
            key :required, true
            key :type, :string
          end
          parameter do
            key :name, :filename
            key :in, :query
            key :description, 'Name/location of file to download'
            key :required, true
            key :type, :string
          end
          response 200 do
            key :description, 'JSON object with media url'
            schema do
              key :type, :object
              key :title, 'File Details'
              property :filename do
                key :type, :string
                key :description, 'Name of file'
              end
              property :url do
                key :type, :string
                key :description, 'Media URL to stream requested file (requires Authorization Bearer token to access)'
              end
              property :access_token do
                key :type, :string
                key :description, 'Authorization bearer token to pass along with media URL request'
              end
            end
          end
          response 403 do
            key :description, 'User is not allowed to view study, or does not have permission to stream file from bucket'
          end
          response 404 do
            key :description, 'Study or StudyFile not found'
          end
          response 406 do
            key :description, 'Accept or Content-Type headers missing or misconfigured'
          end
        end
      end

      def stream_data
        begin
          if @study_file.present?
            filesize = @study_file.upload_file_size
            user_quota = current_api_user.daily_download_quota + filesize
            # check against download quota that is loaded in ApplicationController.get_download_quota
            if user_quota <= @download_quota
              @media_url = @study_file.api_url
              current_api_user.update(daily_download_quota: user_quota)
              # determine which token to return to use with the media url
              if @study.public?
                token = Study.read_only_firecloud_client.valid_access_token['access_token']
              elsif @study.has_bucket_access?(current_api_user)
                token = current_api_user.api_access_token
              else
                alert = 'You do not have permission to stream the requested file from the bucket'
                render json: {error: alert}, status: 403 and return
              end
              render json: {filename: params[:filename], url: @media_url, access_token: token}
            else
              alert = 'You have exceeded your current daily download quota.  You must wait until tomorrow to download this file.'
              render json: {error: alert}, status: 403
            end
          else
            render json: {error: "File not found: #{params[:filename]}"}, status: 404
          end
        rescue RuntimeError => e
          error_context = ErrorTracker.format_extra_context(@study, {params: params})
          ErrorTracker.report_exception(e, current_api_user, error_context)
          logger.error "Error generating signed url for #{params[:filename]}; #{e.message}"
          render json: {error: "Error generating signed url for #{params[:filename]}; #{e.message}"}, status: 500
        end
      end

      swagger_path '/site/analyses' do
        operation :get do
          key :tags, [
              'Site'
          ]
          key :summary, 'Find all available analysis configurations'
          key :description, 'Returns all available analyses configured in SCP'
          key :operationId, 'site_get_analyses_path'
          response 200 do
            key :description, 'Array of AnalysisConfigurations'
            schema do
              key :type, :array
              key :title, 'Array'
              items do
                key :title, 'AnalysisConfigurationList'
                key :'$ref', :AnalysisConfigurationList
              end
            end
          end
          response 406 do
            key :description, 'Accept or Content-Type headers missing or misconfigured'
          end
        end
      end

      def analyses
        @analyses = AnalysisConfiguration.all
      end

      swagger_path '/site/analyses/{namespace}/{name}/{snapshot}' do
        operation :get do
          key :tags, [
              'Site'
          ]
          key :summary, 'Find an analysis configuration'
          key :description, 'Returns analysis configured in SCP with required inputs & default values'
          key :operationId, 'site_get_analysis_path'
          parameter do
            key :name, :namespace
            key :in, :path
            key :description, 'Namespace of AnalysisConfiguration to fetch'
            key :required, true
            key :type, :string
          end
          parameter do
            key :name, :name
            key :in, :path
            key :description, 'Name of AnalysisConfiguration to fetch'
            key :required, true
            key :type, :string
          end
          parameter do
            key :name, :snapshot
            key :in, :path
            key :description, 'Snapshot ID of AnalysisConfiguration to fetch'
            key :required, true
            key :type, :integer
          end
          response 200 do
            key :description, 'Analysis Configuration with input parameters & default values'
            schema do
              key :title, 'AnalysisConfiguration'
              key :'$ref', :AnalysisConfiguration
            end
          end
          response 404 do
            key :description, 'Analysis Configuration not found'
          end
          response 406 do
            key :description, 'Accept or Content-Type headers missing or misconfigured'
          end
        end
      end

      def get_analysis
        @analysis_configuration = AnalysisConfiguration.find_by(namespace: params[:namespace], name: params[:name], snapshot: params[:snapshot].to_i)
      end

      swagger_path '/site/studies/{accession}/analyses/{namespace}/{name}/{snapshot}' do
        operation :get do
          key :tags, [
              'Site'
          ]
          key :summary, 'Get a study-specific analysis configuration'
          key :description, 'Returns analysis configured in for a specific study with available inputs'
          key :operationId, 'site_get_study_analysis_config_path'
          parameter do
            key :name, :accession
            key :in, :path
            key :description, 'Accession of Study to fetch'
            key :required, true
            key :type, :string
          end
          parameter do
            key :name, :namespace
            key :in, :path
            key :description, 'Namespace of AnalysisConfiguration to fetch'
            key :required, true
            key :type, :string
          end
          parameter do
            key :name, :name
            key :in, :path
            key :description, 'Name of AnalysisConfiguration to fetch'
            key :required, true
            key :type, :string
          end
          parameter do
            key :name, :snapshot
            key :in, :path
            key :description, 'Snapshot ID of AnalysisConfiguration to fetch'
            key :required, true
            key :type, :integer
          end
          response 200 do
            key :description, 'Analysis Configuration with study-specific options and default values'
            schema do
              key :title, 'Analysis, Submission Options'
              key :type, :object
              property :analysis do
                key :type, :object
                key :title, 'Analysis'
                property :namespace do
                  key :type, :string
                  key :description, 'Namespace of requested analysis'
                end
                property :name do
                  key :type, :string
                  key :description, 'Name of requested analysis'
                end
                property :snapshot do
                  key :type, :integer
                  key :description, 'Snapshot ID of requested analysis'
                end
                property :entity_type do
                  key :type, :string
                  key :description, 'FireCloud entity type of analysis (may not be present)'
                end
              end
              property :submission_inputs do
                key :type, :array
                key :title, 'Submission Input Options'
                items do
                  property :default_value do
                    key :description, 'Default value (if present)'
                    key :type, :string
                  end
                  property :render_for_user do
                    key :type, :boolean
                    key :description, 'Indication of whether or not to show input to users'
                  end
                  property :input_type do
                    key :type, :string
                    key :description, 'Type of form input for parameter'
                  end
                  property :options do
                    key :type, :array
                    key :title, 'Select Option'
                    key :description, 'Select options if available'
                    items do
                      property :display do
                        key :type, :string
                        key :descrption, 'Display value for select'
                      end
                      property :value do
                        key :type, :string
                        key :description, 'Option value for select'
                      end
                    end
                  end
                end
              end
            end
          end
          response 403 do
            key :description, 'User is not allowed to view/run computes in study'
          end
          response 404 do
            key :description, 'Analysis Configuration or Study not found'
          end
          response 406 do
            key :description, 'Accept or Content-Type headers missing or misconfigured'
          end
        end
      end

      def get_study_analysis_config
        @submission_options = {}
        @analysis_configuration.analysis_parameters.inputs.sort_by(&:config_param_name).each do |parameter|
          @submission_options[parameter.config_param_name] = {
              default_value: parameter.parameter_value,
              render_for_user: parameter.visible,
              input_type: parameter.input_type
          }
          if parameter.input_type == :select
            opts = parameter.options_by_association_method((parameter.study_scoped? || parameter.associated_model == 'Study') ? @study : nil)
            @submission_options[parameter.config_param_name][:options] = opts.map {|option| {display: option.first, value: option.last}}
          end
        end
      end

      swagger_path '/site/studies/{accession}/analyses/{namespace}/{name}/{snapshot}' do
        operation :post do
          key :tags, [
              'Site'
          ]
          key :summary, 'Submit an analysis'
          key :description, 'Submit an analysis to Cromwell'
          key :operationId, 'site_submit_study_analysis_path'
          parameter do
            key :name, :accession
            key :in, :path
            key :description, 'Accession of Study in which to submit analysis'
            key :required, true
            key :type, :string
          end
          parameter do
            key :name, :namespace
            key :in, :path
            key :description, 'Namespace of AnalysisConfiguration to use'
            key :required, true
            key :type, :string
          end
          parameter do
            key :name, :name
            key :in, :path
            key :description, 'Name of AnalysisConfiguration to use'
            key :required, true
            key :type, :string
          end
          parameter do
            key :name, :snapshot
            key :in, :path
            key :description, 'Snapshot ID of AnalysisConfiguration to use'
            key :required, true
            key :type, :integer
          end
          parameter do
            key :name, :submission_inputs
            key :in, :body
            key :description, 'Analysis submission inputs (from GET /site/studies/{accession}/analyses/{namespace}/{name}/{snapshot})'
            key :required, true
            key :type, :object
            key :default, '{"[call_name].[parameter_name]": "\"[value]\""}'
          end
          response 200 do
            key :description, 'Analysis submission information'
          end
          response 400 do
            key :description, 'Malformed submission parameters'
          end
          response 403 do
            key :description, 'User is not allowed to view/run computes in study'
          end
          response 404 do
            key :description, 'Analysis Configuration or Study not found'
          end
          response 406 do
            key :description, 'Accept or Content-Type headers missing or misconfigured'
          end
          response 500 do
            key :description, 'Internal server error (no submission)'
          end
        end
      end

      def submit_study_analysis
        begin
          # before creating submission, we need to make sure that the user is on the 'all-portal' user group list if it exists
          current_api_user.add_to_portal_user_group

          # load analysis configuration
          @analysis_configuration = AnalysisConfiguration.find_by(namespace: params[:namespace], name: params[:name],
                                                                  snapshot: params[:snapshot].to_i)
          submission_inputs = params[:submission_inputs]
          logger.info "Updating configuration for #{@analysis_configuration.configuration_identifier} to run #{@analysis_configuration.identifier} in #{@study.firecloud_project}/#{@study.firecloud_workspace}"
          submission_config = @analysis_configuration.apply_user_inputs(submission_inputs)
          # save configuration in workspace
          Study.firecloud_client.create_workspace_configuration(@study.firecloud_project, @study.firecloud_workspace, submission_config)

          # submission must be done as user, so create a client with current_user and submit
          client = FireCloudClient.new(current_user, @study.firecloud_project)
          logger.info "Creating submission for #{@analysis_configuration.configuration_identifier} using configuration: #{submission_config['name']} in #{@study.firecloud_project}/#{@study.firecloud_workspace}"
          @submission = client.create_workspace_submission(@study.firecloud_project, @study.firecloud_workspace,
                                                           submission_config['namespace'], submission_config['name'],
                                                           submission_config['entityType'], submission_config['entityName'])
          AnalysisSubmission.create(submitter: current_user.email, study_id: @study.id, firecloud_project: @study.firecloud_project,
                                    submission_id: @submission['submissionId'], firecloud_workspace: @study.firecloud_workspace,
                                    analysis_name: @analysis_configuration.identifier, submitted_on: Time.zone.now, submitted_from_portal: true)
        rescue => e
          error_context = ErrorTracker.format_extra_context(@study, {params: params})
          ErrorTracker.report_exception(e, current_api_user, error_context)
          logger.error "Unable to submit workflow #{@analysis_configuration.identifier} in #{@study.firecloud_workspace} due to: #{e.class.name}: #{e.message}"
          alert = "We were unable to submit your workflow due to an error: #{e.class.name}: #{e.message}"
          render json: {error: alert}, status: 500
        end

      end

      swagger_path '/site/studies/{accession}/submissions' do
        operation :get do
          key :tags, [
              'Site'
          ]
          key :summary, 'View all analysis submissions in a Study'
          key :description, 'View all analysis submissions in a given study'
          key :operationId, 'site_get_study_submissions_path'
          parameter do
            key :name, :accession
            key :in, :path
            key :description, 'Accession of Study to fetch'
            key :required, true
            key :type, :string
          end
          response 200 do
            key :description, 'Array of analysis submissions'
          end
          response 403 do
            key :description, 'User is not allowed to view/run computes in study'
          end
          response 404 do
            key :description, 'Study not found'
          end
          response 406 do
            key :description, 'Accept or Content-Type headers missing or misconfigured'
          end
        end
      end

      def get_study_submissions
        workspace = Study.firecloud_client.get_workspace(@study.firecloud_project, @study.firecloud_workspace)
        @submissions = Study.firecloud_client.get_workspace_submissions(@study.firecloud_project, @study.firecloud_workspace)
        # update any AnalysisSubmission records with new statuses
        @submissions.each do |submission|
          update_analysis_submission(submission)
        end
        # remove deleted submissions from list of runs
        if !workspace['workspace']['attributes']['deleted_submissions'].blank?
          deleted_submissions = workspace['workspace']['attributes']['deleted_submissions']['items']
          @submissions.delete_if {|submission| deleted_submissions.include?(submission['submissionId'])}
        end
        render json: @submissions
      end

      swagger_path '/site/studies/{accession}/submissions/{submission_id}' do
        operation :get do
          key :tags, [
              'Site'
          ]
          key :summary, 'View a single analysis submission in a Study'
          key :description, 'View a single analysis submission in a given study'
          key :operationId, 'site_get_study_submission_path'
          parameter do
            key :name, :accession
            key :in, :path
            key :description, 'Accession of Study to fetch'
            key :required, true
            key :type, :string
          end
          parameter do
            key :name, :submission_id
            key :in, :path
            key :description, 'ID of FireCloud submissions to fetch'
            key :required, true
            key :type, :string
          end
          response 200 do
            key :description, 'Analysis submission object w/ individual workflow statuses'
          end
          response 403 do
            key :description, 'User is not allowed to view/run computes in study'
          end
          response 404 do
            key :description, 'Study not found'
          end
          response 406 do
            key :description, 'Accept or Content-Type headers missing or misconfigured'
          end
        end
      end

      def get_study_submission
        @submission = Study.firecloud_client.get_workspace_submission(@study.firecloud_project, @study.firecloud_workspace,
                                                                      params[:submission_id])
        render json: @submission
      end

      swagger_path '/site/studies/{accession}/submissions/{submission_id}' do
        operation :delete do
          key :tags, [
              'Site'
          ]
          key :summary, 'Abort a single analysis submission in a Study'
          key :description, 'Abort a single analysis submission in a given study'
          key :operationId, 'site_abort_study_submission_path'
          parameter do
            key :name, :accession
            key :in, :path
            key :description, 'Accession of Study to fetch'
            key :required, true
            key :type, :string
          end
          parameter do
            key :name, :submission_id
            key :in, :path
            key :description, 'ID of FireCloud submission to abort'
            key :required, true
            key :type, :string
          end
          response 204 do
            key :description, 'Analysis submission successfully aborted'
          end
          response 403 do
            key :description, 'User is not allowed to view/run computes in study'
          end
          response 404 do
            key :description, 'Study not found'
          end
          response 406 do
            key :description, 'Accept or Content-Type headers missing or misconfigured'
          end
          response 412 do
            key :description, 'Analysis submission has already completed running and cannot be aborted anymore'
          end
        end
      end

      def abort_study_submission
        if !submission_completed?(@study, params[:submission_id])
          begin
            Study.firecloud_client.abort_workspace_submission(@study.firecloud_project, @study.firecloud_workspace,
                                                              params[:submission_id])
            analysis_submission = AnalysisSubmission.find_by(submission_id: params[:submission_id])
            if analysis_submission.present?
              analysis_submission.update(status: 'Aborted', completed_on: Time.zone.now)
            end
            head 204
          rescue => e
            error_context = ErrorTracker.format_extra_context(@study, {params: params})
            ErrorTracker.report_exception(e, current_api_user, error_context)
            logger.error "Unable to abort submission: #{params[:submission_id]} due to error: #{e.message}"
            render json: {error: "#{e.class.name}: #{e.message}"}, status: 500
          end
        else
          render json: {error: "Cannot abort a completed submission; #{params[:submission_id]} has already finished."}, status: 412
        end
      end

      swagger_path '/site/studies/{accession}/submissions/{submission_id}/remove' do
        operation :delete do
          key :tags, [
              'Site'
          ]
          key :summary, 'Delete an analysis submission bucket directory'
          key :description, 'Delete an single analysis submission workspace bucket directory.  Will only work for completed submissions'
          key :operationId, 'site_abort_study_submission_path'
          parameter do
            key :name, :accession
            key :in, :path
            key :description, 'Accession of Study to fetch'
            key :required, true
            key :type, :string
          end
          parameter do
            key :name, :submission_id
            key :in, :path
            key :description, 'ID of FireCloud submission from which to remove bucket submission directory'
            key :required, true
            key :type, :string
          end
          response 204 do
            key :description, 'Analysis submission bucket directory successfully deleted'
          end
          response 403 do
            key :description, 'User is not allowed to view/run computes in study'
          end
          response 404 do
            key :description, 'Study not found'
          end
          response 406 do
            key :description, 'Accept or Content-Type headers missing or misconfigured'
          end
          response 412 do
            key :description, 'Analysis submission is still running; cannot remove bucket submission directory'
          end
        end
      end

      def delete_study_submission_dir
        if submission_completed?(@study, params[:submission_id])
          begin
            # first, add submission to list of 'deleted_submissions' in workspace attributes (will hide submission in list)
            workspace = Study.firecloud_client.get_workspace(@study.firecloud_project, @study.firecloud_workspace)
            ws_attributes = workspace['workspace']['attributes']
            if ws_attributes['deleted_submissions'].blank?
              ws_attributes['deleted_submissions'] = [params[:submission_id]]
            else
              ws_attributes['deleted_submissions']['items'] << params[:submission_id]
            end
            logger.info "Adding #{params[:submission_id]} to workspace delete_submissions attribute in #{@study.firecloud_workspace}"
            Study.firecloud_client.set_workspace_attributes(@study.firecloud_project, @study.firecloud_workspace, ws_attributes)
            logger.info "Deleting analysis metadata for #{params[:submission_id]} in #{@study.url_safe_name}"
            AnalysisMetadatum.where(submission_id: params[:submission_id]).delete
            logger.info "Queueing submission #{params[:submission]} deletion in #{@study.firecloud_workspace}"
            submission_files = Study.firecloud_client.execute_gcloud_method(:get_workspace_files, 0, @study.firecloud_project, @study.firecloud_workspace, prefix: params[:submission_id])
            DeleteQueueJob.new(submission_files).perform
            head 204
          rescue => e
            error_context = ErrorTracker.format_extra_context(@study, {params: params})
            ErrorTracker.report_exception(e, current_user, error_context)
            logger.error "Unable to remove submission #{params[:submission_id]} files from #{@study.firecloud_workspace} due to: #{e.class.name}: #{e.message}"
            render json: {error: "Unable to delete the outputs for #{params[:submission_id]} due to the following error: #{e.class.name}: #{e.message}"}, status: 500
          end
        else
          render json: {error: "Cannot remove bucket directory of a running submission; #{params[:submission_id]} has not yet completed"}, status: 412
        end
      end

      def sync_submission_outputs

      end

      private

      ##
      # Setters
      ##

      def set_study
        @study = Study.find_by(accession: params[:accession])
        if @study.nil? || @study.queued_for_deletion?
          head 404 and return
        end
      end

      def set_study_file
        @study_file = @study.study_files.detect {|file| file.upload_file_name == params[:filename] || file.bucket_location == params[:filename]}
      end

      def set_analysis_configuration
        @analysis_configuration = AnalysisConfiguration.find_by(namespace: params[:namespace], name: params[:name], snapshot: params[:snapshot].to_i)
      end

      ##
      # Permission checks
      ##

      def check_study_view_permission
        head 403 unless @study.public? || @study.can_view?(current_api_user)
      end

      def check_study_edit_permission
        head 403 unless @study.can_edit?(current_api_user)
      end

      def check_study_compute_permission
        head 403 unless @study.can_compute?(current_api_user)
      end

      # retrieve the current download quota
      def get_download_quota
        config_entry = AdminConfiguration.find_by(config_type: 'Daily User Download Quota')
        if config_entry.nil? || config_entry.value_type != 'Numeric'
          # fallback in case entry cannot be found or is set to wrong type
          @download_quota = 2.terabytes
        else
          @download_quota = config_entry.convert_value_by_type
        end
      end

      # update AnalysisSubmissions when loading study analysis tab
      # will not backfill existing workflows to keep our submission history clean
      def update_analysis_submission(submission)
        analysis_submission = AnalysisSubmission.find_by(submission_id: submission['submissionId'])
        if analysis_submission.present?
          workflow_status = submission['workflowStatuses'].keys.first # this only works for single-workflow analyses
          analysis_submission.update(status: workflow_status)
          analysis_submission.delay.set_completed_on # run in background to avoid UI blocking
        end
      end

      # boolean check for submission completion
      def submission_completed?(study, submission_id)
        submission = Study.firecloud_client.get_workspace_submission(study.firecloud_project, study.firecloud_workspace,
                                                                     submission_id)
        last_workflow = submission['workflows'].sort_by {|w| w['statusLastChangedDate']}.last
        AnalysisSubmission::COMPLETION_STATUSES.include?(last_workflow['status'])
      end
    end
  end
end
