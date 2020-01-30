module Api
  module V1
    class SearchController < ApiBaseController
      include Concerns::Authenticator
      include Swagger::Blocks

      before_action :set_current_api_user!
      before_action :set_search_facet, only: :facet_filters
      before_action :set_search_facets_and_filters, only: :index

      swagger_path '/search' do
        operation :get do
          key :tags, [
              'Search'
          ]
          key :summary, 'Faceted & keyword search for studies & cells'
          key :description, 'Search studies or cells using facets and keywords'
          key :operationId, 'search_studies'
          parameter do
            key :name, :type
            key :in, :query
            key :description, 'Type of query to perform (study- or cell-based)'
            key :required, true
            key :type, :string
            key :enum, ['study', 'cell']
          end
          parameter do
            key :name, :facets
            key :in, :query
            key :description, 'User-supplied list facets and filters, formatted as: "facet_id:filter_value+facet_id_2:filter_value_2,filter_value_3"'
            key :required, false
            key :type, :string
          end
          parameter do
            key :name, :terms
            key :in, :query
            key :description, 'User-supplied query string'
            key :required, false
            key :type, :string
          end
          response 200 do
            key :description, 'Search parameters, Studies and StudyFiles'
            schema do
              key :title, 'Search Results'
              property :type do
                key :type, :string
                key :description, 'Type of search performed'
              end
              property :terms do
                key :type, :string
                key :title, 'Keywords used in search'
              end
              property :page do
                key :type, :string
                key :title, 'Pagination control'
              end
              property :facets do
                key :type, :array
                key :title, 'SearchFacets'
                key :description, 'Array of facets/filters used in search'
                items do
                  key :type, :object
                  key :title, 'SearchFacet'
                  property :id do
                    key :type, :string
                    key :description, 'ID of facet'
                  end
                  property :filters do
                    key :type, :array
                    key :description, 'Matching filters'
                    items do
                      key :type, :object
                      key :title, 'Filter'
                      property :name do
                        key :type, :string
                        key :description, 'Display value of filter'
                      end
                      property :id do
                        key :type, :string
                        key :description, 'ID value of filter'
                      end
                    end
                  end
                end
              end
              property :studies do
                key :type, :array
                items do
                  key :title, 'Study, StudyFiles'
                  key :'$ref', :SiteStudyWithFiles
                end
              end
            end
          end
          response 406 do
            key :description, 'Accept or Content-Type headers missing or misconfigured'
          end
        end
      end

      def index
        order = [:view_order.asc, :name.asc]
        if api_user_signed_in?
          @viewable = Study.viewable(current_user).order_by(order)
        else
          @viewable = Study.where(public: true).order_by(order)
        end

        # if search params are present, filter accordingly
        if !params[:terms].blank?
          search_terms = sanitize_search_values(params[:terms])
          # determine if search values contain possible study accessions
          possible_accessions = StudyAccession.sanitize_accessions(search_terms.split)
          @studies = @viewable.any_of({:$text => {:$search => search_terms}}, {:accession.in => possible_accessions})
        else
          @studies = @viewable
        end

        # only call BigQuery if list of possible studies is larger than 0 and we have matching facets to use
        if @studies.count > 0 && @facets.any?
          @big_query_search = generate_bq_query_string(@facets)
          Rails.logger.info "Searching BigQuery using facet-based query: #{@big_query_search}"
          raw_accessions = ApplicationController.big_query_client.dataset(CellMetadatum::BIGQUERY_DATASET).query @big_query_search
          job_id = raw_accessions.job_gapi.job_reference.job_id
          @convention_accessions = raw_accessions.map {|match| match[:study_accession]}
          Rails.logger.info "Found #{@convention_accessions.count} matching studies from BQ job #{job_id}: #{@convention_accessions}"
          @studies = @studies.where(:accession.in => @convention_accessions)
        end
        # paginate results
        @studies.paginate(page: params[:page], per_page: Study.per_page)
      end

      swagger_path '/search/facets' do
        operation :get do
          key :tags, [
              'Search'
          ]
          key :summary, 'Get all available facets'
          key :description, 'Returns a list of all available search facets, including filter values'
          key :operationId, 'search_facets_path'
          response 200 do
            key :description, 'Array of SearchFacets'
            schema do
              key :type, :array
              key :title, 'Array'
              items do
                key :title, 'SearchFacetConfig'
                key :'$ref', :SearchFacetConfig
              end
            end
          end
          response 406 do
            key :description, 'Accept or Content-Type headers missing or misconfigured'
          end
        end
      end

      def facets
        @search_facets = SearchFacet.all
      end

      swagger_path '/search/facet_filters' do
        operation :get do
          key :tags, [
              'Search'
          ]
          key :summary, 'Search matching filters for a facet'
          key :description, 'Returns a list of matching facet filters for a given facet'
          key :operationId, 'search_facet_filters_path'
          parameter do
            key :name, :facet
            key :in, :query
            key :description, 'Identifier of facet'
            key :required, true
            key :type, :string
          end
          parameter do
            key :name, :query
            key :in, :query
            key :description, 'User-supplied query string'
            key :required, true
            key :type, :string
          end
          response 200 do
            key :description, 'SearchFacet with matching filters'
            schema do
              key :title, 'SearchFacetQuery'
              key :'$ref', :SearchFacetQuery
            end
          end
          response 406 do
            key :description, 'Accept or Content-Type headers missing or misconfigured'
          end
        end
      end

      def facet_filters
        # sanitize query string for regexp matching
        @query_string = params[:query]
        query_matcher = /#{Regexp.escape(@query_string)}/i
        @matching_filters = @search_facet.filters.select {|filter| filter[:name] =~ query_matcher}
      end

      private

      def set_search_facet
        @search_facet = SearchFacet.find_by(identifier: params[:facet])
      end

      def set_search_facets_and_filters
        @facets = []
        facet_queries = params[:facets].split('+')
        facet_queries.each do |query|
          facet_id, raw_filters = query.split(':')
          filter_values = raw_filters.split(',')
          facet = SearchFacet.find_by(identifier: facet_id)
          if facet.present?
            matching_filters = []
            facet.filters.each do |filter|
              if filter_values.include?(filter[:id])
                matching_filters << filter
              end
            end
            if matching_filters.any?
              @facets << {
                  id: facet.identifier,
                  filters: matching_filters,
                  object_id: facet.id # used for lookup later in :generate_bq_query_string
              }
            end
          end
        end
      end

      # sanitize search values
      def sanitize_search_values(terms)
        if terms.is_a?(Array)
          sanitized = terms.map {|t| view_context.sanitize(t)}
          sanitized.join(',')
        else
          view_context.sanitize(terms)
        end
      end

      # generate query string for BQ
      def generate_bq_query_string(facets)
        base_query = "SELECT DISTINCT study_accession FROM #{CellMetadatum::BIGQUERY_TABLE} WHERE "
        sub_queries = []
        facets.each do |facet_obj|
          # get the facet instance in order to run query
          search_facet = SearchFacet.find(facet_obj[:object_id])
          column_name = search_facet.big_query_id_column
          if search_facet.is_array_based?
            filter_values = facet_obj[:filters].map {|filter| filter[:id]}
            unnest_queries = []
            filter_values.each do |value|
              unnest_queries << "'#{value}' IN UNNEST(#{column_name})"
            end
            sub_queries << "(#{unnest_queries.join(" OR ")})"
          else
            filter_values = facet_obj[:filters].map {|filter| filter[:id]}
            sub_queries << "#{column_name} IN ('#{filter_values.join('\',\'')}')"
          end
        end
        base_query += sub_queries.join(" AND ")
      end
    end
  end
end

