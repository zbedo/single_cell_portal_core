module Api
  module V1
    class ExpressionViolinsController < ApiBaseController
      include Concerns::Authenticator
      include Concerns::StudyAware
      include Swagger::Blocks

      before_action :set_current_api_user!
      before_action :set_study
      before_action :check_study_view_permission


      # Returns the expression data for the gene within the given study, optimized for rendering
      # by the SCP UI.
      # We agreed that there would be no swagger docs for this endpoint, as it is not intended
      # to be used other than by the SCP UI, and may change dramatically
      def index
        cluster = ApiParamUtils.get_cluster_group(params, @study)
        selected_annotation = ApiParamUtils.get_selected_annotation(params, @study, cluster)
        subsample = params[:subsample].blank? ? nil : params[:subsample].to_i
        gene = @study.genes.by_name_or_id(params[:gene], @study.expression_matrix_files.map(&:id))

        render_data = ExpressionRenderingService.get_global_expression_render_data(
          @study, subsample, gene, cluster, selected_annotation, params[:boxpoints], current_user
        )
        render json: render_data, status: 200
      end


    end
  end
end
