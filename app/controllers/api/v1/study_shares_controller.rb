module Api
  module V1
    class StudySharesController < ApiBaseController

      before_action :set_study
      before_action :check_study_permission
      before_action :set_study_share, except: [:index, :create, :schema]
      before_action :check_firecloud_status, except: [:index, :show]

      # GET /single_cell/api/v1/studies/:study_id
      def index
        @study_shares = @study.study_shares
        render json: @study_shares.map(&:attributes)
      end

      # GET /single_cell/api/v1/studies/:study_id/study_files/:id
      def show
        render json: @study_share.attributes
      end

      # POST /single_cell/api/v1/studies/:study_id/study_files
      def create
        @study_share = @study.study_shares.build(study_share_params)

        if @study_share.save
          render json: @study_share.attributes, status: :ok
        else
          render json: {errors: @study_share.errors}, status: :unprocessable_entity
        end
      end

      # PATCH /single_cell/api/v1/studies/:study_id/study_files/:id
      def update
        if @study_share.update(study_share_params)
          render json: @study_share.attributes, status: :ok
        else
          render json: {errors: @study_share.errors}, status: :unprocessable_entity
        end
      end

      # DELETE /single_cell/api/v1/studies/:study_id/study_files/:id
      def destroy
        begin
          @study_share.destroy
          head 204
        rescue => e
          render json: {error: e.message}, status: 500
        end
      end

      private

      def set_study
        @study = Study.find_by(id: params[:study_id])
        if @study.nil? || @study.queued_for_deletion?
          head 404 and return
        end
      end

      def set_study_share
        @study_share = StudyShare.find_by(id: params[:id])
        if @study_share.nil?
          head 404 and return
        end
      end

      def check_study_permission
        head 403 unless @study.can_edit?(current_api_user)
      end

      # study file params whitelist
      def study_share_params
        params.require(:study_share).permit(:id, :study_id, :email, :permission, :deliver_emails)
      end

      # check on FireCloud API status and respond accordingly
      def check_firecloud_status
        unless Study.firecloud_client.services_available?('Sam', 'Rawls')
          alert = 'Study workspaces are temporarily unavailable, so we cannot complete your request.  Please try again later.'
          render json: {error: alert}, status: 503
        end
      end
    end
  end
end

