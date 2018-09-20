module Api
  module V1
    class StudySharesController < ApiBaseController

      include Concerns::FireCloudStatus

      before_action :set_study
      before_action :check_study_permission
      before_action :set_study_share, except: [:index, :create]

      respond_to :json

      # GET /single_cell/api/v1/studies/:study_id
      def index
        @study_shares = @study.study_shares
      end

      # GET /single_cell/api/v1/studies/:study_id/study_shares/:id
      def show

      end

      # POST /single_cell/api/v1/studies/:study_id/study_shares
      def create
        @study_share = @study.study_shares.build(study_share_params)

        if @study_share.save
          render :show
        else
          render json: {errors: @study_share.errors}, status: :unprocessable_entity
        end
      end

      # PATCH /single_cell/api/v1/studies/:study_id/study_shares/:id
      def update
        if @study_share.update(study_share_params)
          render :show
        else
          render json: {errors: @study_share.errors}, status: :unprocessable_entity
        end
      end

      # DELETE /single_cell/api/v1/studies/:study_id/study_shares/:id
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
    end
  end
end

