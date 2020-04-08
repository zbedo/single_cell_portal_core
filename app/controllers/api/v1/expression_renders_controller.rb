module Api
  module V1
    class ExpressionRendersController < ApiBaseController
      include Concerns::Authenticator
      include Swagger::Blocks

      def index
        study = Study.find_by!(accession: params[:study_id])
        cluster = ApiParamUtils.get_cluster_group(params, study)
        selected_annotation = ApiParamUtils.get_selected_annotation(params, study, cluster)
        subsample = params[:subsample].blank? ? nil : params[:subsample].to_i
        gene = study.genes.by_name_or_id(params[:genes], study.expression_matrix_files.map(&:id))
        render_data = ExpressionRenderingService.get_global_expression_render_data(
          study, subsample, gene, cluster, selected_annotation, params[:boxpoints], current_user
        )
        render json: render_data, status: 200
      end
    end
  end
end
