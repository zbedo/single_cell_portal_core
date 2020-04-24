module Api
  module V1
    class ExpressionDataController < ApiBaseController
      include Concerns::Authenticator
      include Concerns::StudyAware
      include Swagger::Blocks

      before_action :set_current_api_user!
      before_action :set_study
      before_action :check_study_view_permission


      # Returns the specified expression data for the gene within the given study, optimized for rendering
      # by the SCP UI.
      swagger_path '/site/studies/{accession}/expression_data/{data_type}' do
        operation :get do
          key :tags, [
              'ExpressionData'
          ]
          key :summary, 'Retrieve gene expression data from a study'
          key :description, 'Returns all Studies viewable by the current user, including public studies'
          key :operationId, 'site_expression_data_path'
          parameter do
            key :name, :accession
            key :in, :path
            key :description, 'Accession of study to query expression data from'
            key :required, true
            key :type, :string
          end
          parameter do
            key :name, :data_type
            key :in, :path
            key :description, 'Type of data to return'
            key :required, true
            key :type, :string
            key :enum, ['violin', 'annotations']
          end
          parameter do
            key :name, :gene
            key :in, :query
            key :description, 'Gene to load expression data from'
            key :required, false
            key :type, :string
          end
          parameter do
            key :name, :cluster
            key :in, :query
            key :description, 'Name of cluster to show expression data overlaid on'
            key :required, false
            key :type, :string
          end
          parameter do
            key :name, :annotation
            key :in, :query
            key :description, 'Name of annotation to group expression data with'
            key :format, '{annotation name}--{annotation type}--{annotation scope}'
            key :required, false
            key :type, :string
          end
          response 200 do
            key :description, 'Expression or Annotation data object'
          end
          response 400 do
            key :description, 'Unknown data type'
          end
        end
      end

      def show
        if (!@study.has_expression_data? || !@study.can_visualize_clusters?)
          render json: {error: "Study #{@study.accession} does not support expression rendering"}, status: 400
        end
        data_type = params[:data_type]
        if (data_type == 'violin')
          render_violin
        elsif (data_type == 'annotations')
          render_annotation_values
        else
          render json: {error: "Unknown expression data type: #{data_type}"}, status: 400
        end

      end

      def render_violin
        cluster = RequestUtils.get_cluster_group(params, @study)
        selected_annotation = RequestUtils.get_selected_annotation(params, @study, cluster)
        subsample = params[:subsample].blank? ? nil : params[:subsample].to_i
        gene = @study.genes.by_name_or_id(params[:gene], @study.expression_matrix_files.map(&:id))

        render_data = ExpressionRenderingService.get_global_expression_render_data(
          @study, subsample, gene, cluster, selected_annotation, params[:boxpoints], current_api_user
        )
        render json: render_data, status: 200
      end

      def render_annotation_values
        cluster = RequestUtils.get_cluster_group(params, @study)
        annotation = RequestUtils.get_selected_annotation(params, @study, cluster)
        render json: annotation, status: 200
      end
    end
  end
end
