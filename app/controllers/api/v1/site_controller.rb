module Api
  module V1
    class SiteController < ApiBaseController
      include Concerns::SiteAuthenticator

      before_action :set_study, except: [:studies]
      before_action :check_study_permission, except: [:studies]

      def studies
        if api_user_signed_in?
          @studies = Study.viewable(current_api_user)
        else
          @studies = Study.where(public: true)
        end
      end

      def view_study

      end

      def download_data
        begin
          # get filesize and make sure the user is under their quota
          requested_file = Study.firecloud_client.execute_gcloud_method(:get_workspace_file, 0, @study.firecloud_project, @study.firecloud_workspace, params[:filename])
          if requested_file.present?
            filesize = requested_file.size
            user_quota = current_api_user.daily_download_quota + filesize
            # check against download quota that is loaded in ApplicationController.get_download_quota
            if user_quota <= @download_quota
              @signed_url = Study.firecloud_client.execute_gcloud_method(:generate_signed_url, 0, @study.firecloud_project, @study.firecloud_workspace, params[:filename], expires: 15)
              current_api_user.update(daily_download_quota: user_quota)
              redirect_to @signed_url
            else
              alert = 'You have exceeded your current daily download quota.  You must wait until tomorrow to download this file.'
              render json: {error: alert, status: 403}
            end
          else
            render json: {error: "File not found: #{params[:filename]}", status: 404}
          end
        rescue RuntimeError => e
          error_context = ErrorTracker.format_extra_context(@study, {params: params})
          ErrorTracker.report_exception(e, current_api_user, error_context)
          logger.error "Error generating signed url for #{params[:filename]}; #{e.message}"
          render json: {error: "Error generating signed url for #{params[:filename]}; #{e.message}", status: 500}
        end
      end

      def stream_data
        begin
          # get filesize and make sure the user is under their quota
          requested_file = Study.firecloud_client.execute_gcloud_method(:get_workspace_file, 0, @study.firecloud_project, @study.firecloud_workspace, params[:filename])
          if requested_file.present?
            filesize = requested_file.size
            user_quota = current_api_user.daily_download_quota + filesize
            # check against download quota that is loaded in ApplicationController.get_download_quota
            if user_quota <= @download_quota
              @media_url = Study.firecloud_client.execute_gcloud_method(:generate_api_url, 0, @study.firecloud_project, @study.firecloud_workspace, params[:filename])
              current_api_user.update(daily_download_quota: user_quota)
              render json: {filename: params[:filename], url: @media_url}
            else
              alert = 'You have exceeded your current daily download quota.  You must wait until tomorrow to download this file.'
              render json: {error: alert, status: 403}
            end
          else
            render json: {error: "File not found: #{params[:filename]}", status: 404}
          end
        rescue RuntimeError => e
          error_context = ErrorTracker.format_extra_context(@study, {params: params})
          ErrorTracker.report_exception(e, current_api_user, error_context)
          logger.error "Error generating signed url for #{params[:filename]}; #{e.message}"
          render json: {error: "Error generating signed url for #{params[:filename]}; #{e.message}", status: 500}
        end
      end

      private

      def set_study
        @study = Study.find_by(accession: params[:accession])
        if @study.nil? || @study.queued_for_deletion?
          head 404 and return
        end
      end

      def check_study_permission
        head 403 unless @study.can_view?(current_api_user)
      end
    end
  end
end
