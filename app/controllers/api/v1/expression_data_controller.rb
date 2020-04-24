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
      swagger_path '/site/studies/{accession}/expression_data/violin' do
        operation :get do
          key :tags, [
              'ExpressionData'
          ]
          key :summary, 'Retrieve single gene expression data from a study'
          key :description, 'Returns a distribution of gene expression data for a given gene/cluster/annotation'
          key :operationId, 'site_study_expression_violin'
          parameter do
            key :name, :accession
            key :in, :path
            key :description, 'Accession of study to query expression data from'
            key :required, true
            key :type, :string
          end
          parameter do
            key :name, :gene
            key :in, :query
            key :description, 'Gene to load expression data from'
            key :required, true
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
            key :description, 'Name of annotation to group expression data with ({annotation_name}--{annotation_type}--{annotation_scope})'
            key :required, false
            key :type, :string
          end
          parameter do
            key :name, :subsample
            key :in, :query
            key :description, 'Threshold at which to subsample expression data'
            key :required, false
            key :type, :integer
            key :enum, [ClusterGroup::SUBSAMPLE_THRESHOLDS]
          end
          response 200 do
            key :description, 'Expression or Annotation data object'
          end
          response 400 do
            key :description, 'Bad request - study has no expression data, or unknown data type'
          end
        end
      end

      def violin
        if (!@study.has_expression_data? || !@study.can_visualize_clusters?)
          render json: {error: "Study #{@study.accession} does not support expression rendering"}, status: 400
        elsif params[:gene].blank?
          render json: {error: 'Cannot load expression data without a gene specified'}, status: 400
        end
        render_violin
      end

      swagger_path '/site/studies/{accession}/expression_data/heatmap' do
        operation :get do
          key :tags, [
              'ExpressionData'
          ]
          key :summary, 'Retrieve a subsetted expression matrix for a list of genes'
          key :description, 'Returns a subsetted expression matrix for a list of genes and a given cluster'
          key :operationId, 'site_study_expression_heatmap'
          parameter do
            key :name, :accession
            key :in, :path
            key :description, 'Accession of study to query expression data from'
            key :required, true
            key :type, :string
          end
          parameter do
            key :name, :genes
            key :in, :query
            key :description, 'Genes to load expression data from (URL-encoded list, plus-delimited)'
            key :required, true
            key :type, :string
          end
          parameter do
            key :name, :cluster
            key :in, :query
            key :description, 'Name of cluster to show expression data overlaid on'
            key :required, false
            key :type, :string
          end
          response 200 do
            key :description, 'Expression or Annotation data object'
          end
          response 400 do
            key :description, 'Bad request - study has no expression data, or unknown data type'
          end
        end
      end

      def heatmap
        if (!@study.has_expression_data? || !@study.can_visualize_clusters?)
          render json: {error: "Study #{@study.accession} does not support expression rendering"}, status: 400
        elsif params[:genes].blank?
          render json: {error: 'Cannot load expression data without genes specified'}, status: 400
        end
        get_heatmap_data
      end

      swagger_path '/site/studies/{accession}/annotations/{data_type}' do
        operation :get do
          key :tags, [
              'ExpressionData'
          ]
          key :summary, 'Retrieve annotation data for a given study'
          key :description, 'Returns either a JSON object describing an annotation, or a TSV file of annotated cells'
          key :operationId, 'site_study_expression_get_annotations'
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
            key :description, 'Type of data requested'
            key :required, true
            key :type, :string
            key :enum, %w(json text)
          end
          parameter do
            key :name, :annotation
            key :in, :query
            key :description, 'Name of annotation in ({annotation_name}--{annotation_type}--{annotation_scope})'
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
          response 200 do
            key :description, 'Annotation object of requested type'
          end
          response 400 do
            key :description, 'Bad request - study has no expression data, or unknown data type'
          end
        end
      end

      def annotations
        if !@study.can_visualize_clusters?
          render json: {error: "Study #{@study.accession} does not support cluster/annotation rendering"}, status: 400
        elsif params[:data_type].blank?
          render json: {error: 'Must specify response data type'}, status: 400
        end
        case params[:data_type].to_sym
        when :json
          annotation_values
        when :text
          cells_by_annotation
        end
      end

      def annotation_values
        cluster = RequestUtils.get_cluster_group(params, @study)
        annotation = RequestUtils.get_selected_annotation(params, @study, cluster)
        render json: annotation, status: 200
      end

      def cells_by_annotation
        cluster = RequestUtils.get_cluster_group(params, @study)
        annotation = RequestUtils.get_selected_annotation(params, @study, cluster)
        annotated_cells = ExpressionRenderingService.get_morpheus_text_data(
            study: @study, cluster: cluster, selected_annotation: annotation, file_type: :annotation
        )

        send_data annotated_cells, type: 'text/plain', status: 200
      end

      def render_violin
        cluster = RequestUtils.get_cluster_group(params, @study)
        selected_annotation = RequestUtils.get_selected_annotation(params, @study, cluster)
        subsample = params[:subsample].blank? ? nil : params[:subsample].to_i
        gene = @study.genes.by_name_or_id(params[:gene], @study.expression_matrix_files.map(&:id))

        render_data = ExpressionRenderingService.get_single_gene_expression_render_data(
          @study, subsample, gene, cluster, selected_annotation, params[:boxpoints], current_api_user
        )
        render json: render_data, status: 200
      end

      def get_heatmap_data
        cluster = RequestUtils.get_cluster_group(params, @study)
        terms = RequestUtils.sanitize_search_param(params[:genes])
        matrix_ids = @study.expression_matrix_files.map(&:id)
        collapse_by = params[:row_centered]

        genes = []
        terms.each do |term|
          matches = @study.genes.by_name_or_id(term, matrix_ids)
          unless matches.empty?
            genes << matches
          end
        end
        expression_data = ExpressionRenderingService.get_morpheus_text_data(
            genes: genes, cluster: cluster, collapse_by: collapse_by, file_type: :gct
        )

        send_data expression_data, type: 'text/plain', status: 200
      end
    end
  end
end
