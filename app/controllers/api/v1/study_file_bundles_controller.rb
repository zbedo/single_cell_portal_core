module Api
  module V1
    class StudyFileBundlesController < ApiBaseController

      before_action :set_study
      before_action :check_study_permission
      before_action :set_study_file_bundle, except: [:index, :create]

      respond_to :json

      # GET /single_cell/api/v1/studies/:study_id/study_file_bundles
      def index
        @study_file_bundles = @study.study_file_bundles

      end

      # GET /single_cell/api/v1/studies/:study_id/study_file_bundles/:id
      def show

      end

      # POST /single_cell/api/v1/studies/:study_id/study_file_bundles
      def create
        @study_file_bundle = @study.study_file_bundles.build(study_file_bundle_params)

        if @study_file_bundle.save
          render :show
        else
          render json: {errors: @study_file_bundle.errors}, status: :unprocessable_entity
        end
      end

      # DELETE /single_cell/api/v1/studies/:study_id/study_file_bundles/:id
      def destroy
        begin
          @study_file_bundle.destroy
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

      def set_study_file_bundle
        @study_file_bundle = StudyFileBundle.find_by(id: params[:id])
        if @study_file_bundle.nil?
          head 404 and return
        end
      end

      def check_study_permission
        head 403 unless @study.can_edit?(current_api_user)
      end

      # study file params whitelist
      def study_file_bundle_params
        params.require(:study_file_bundle).permit(:bundle_type, original_file_list: [:name, :file_type, :species, :assembly])
      end
    end
  end
end

