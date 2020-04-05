module Api
  module V1
    class GenesController < ApiBaseController
      include Concerns::Authenticator
      include Swagger::Blocks

      def index
        study = Study.find_by!(accession: params[:study_id])
        # byebug

        # subsample = params[:subsample].blank? ? nil : params[:subsample].to_i
        # @gene = @study.genes.by_name_or_id(params[:gene], @study.expression_matrix_files.map(&:id))
        # @identifier = params[:identifier] # unique identifer for each plot for namespacing JS variables/functions (@gene.id)
        # @target = 'study-' + @study.id + '-gene-' + @identifier
        # @y_axis_title = load_expression_axis_title
        # if @selected_annotation[:type] == 'group'
        #   @values = load_expression_boxplot_data_array_scores(@selected_annotation, subsample)
        #   @values_jitter = params[:boxpoints]
        # else
        #   @values = load_annotation_based_data_array_scatter(@selected_annotation, subsample)
        # end
        # @options = load_cluster_group_options
        # @cluster_annotations = load_cluster_group_annotations
      end
    end
  end
end
