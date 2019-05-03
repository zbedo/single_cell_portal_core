module Api
  module V1
    class SiteController < ApiBaseController
      include Concerns::Authenticator
      include Swagger::Blocks

      before_action :set_current_api_user!
      before_action :set_study, except: [:studies, :analyses, :get_analysis]
      before_action :set_analysis_configuration, only: [:get_analysis, :get_study_analysis_config]
      before_action :check_study_permission, except: [:studies, :analyses, :get_analysis]
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
              end
              property :submission_options do
                key :type, :array
                key :title, 'Submission Options'
                items do
                  property :default_value do
                    key :description, 'Default value (if present)'
                    key :type, :string
                  end
                  property :render_for_user do
                    key :type, :boolean
                    key :description, 'Indication of whether or not to show input to users'
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
            key :description, 'User is not allowed to view study'
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
              render_for_user: parameter.visible
          }
          if parameter.input_type == :select
            opts = parameter.options_by_association_method((parameter.study_scoped? || parameter.associated_model == 'Study') ? @study : nil)
            @submission_options[parameter.config_param_name][:options] = opts.map {|option| {display: option.first, value: option.last}}
          end
        end
      end

      def submit_study_analysis

      end

      def get_study_submissions

      end

      def get_study_submission

      end

      def sync_submission_outputs

      end

      private

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

      def check_study_permission
        head 403 unless @study.public? || @study.can_view?(current_api_user)
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
    end
  end
end
