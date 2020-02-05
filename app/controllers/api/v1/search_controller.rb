module Api
  module V1
    class SearchController < ApiBaseController
      include Concerns::Authenticator
      include Swagger::Blocks

      before_action :set_current_api_user!
      before_action :authenticate_api_user!, only: [:create_auth_code, :bulk_download]
      before_action :set_search_facet, only: :facet_filters
      before_action :set_search_facets_and_filters, only: :index

      swagger_path '/search' do
        operation :get do
          key :tags, [
              'Search'
          ]
          key :summary, 'Faceted & keyword search for studies & cells'
          key :description, 'Search studies or cells using facets and keywords.'
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
                  key :'$ref', :SearchStudyWithFiles
                end
              end
            end
          end
          response 406 do
            key :description, 'Accept or Content-Type headers missing or misconfigured'
          end
          response 500 do
            key :description, 'Server error'
          end
        end
      end

      def index
        @viewable = Study.viewable(current_api_user)

        # if search params are present, filter accordingly
        if params[:terms].present?
          @search_terms = sanitize_search_values(params[:terms])
          # determine if search values contain possible study accessions
          possible_accessions = StudyAccession.sanitize_accessions(@search_terms.split)
          @studies = @viewable.any_of({:$text => {:$search => @search_terms}},
                                      {:accession.in => possible_accessions}).order_by {|study| study.search_weight(@search_terms.split) }
        else
          @studies = @viewable
        end

        # only call BigQuery if list of possible studies is larger than 0 and we have matching facets to use
        if @studies.count > 0 && @facets.any?
          @studies_by_facet = {}
          @big_query_search = self.class.generate_bq_query_string(@facets)
          Rails.logger.info "Searching BigQuery using facet-based query: #{@big_query_search}"
          query_results = ApplicationController.big_query_client.dataset(CellMetadatum::BIGQUERY_DATASET).query @big_query_search
          job_id = query_results.job_gapi.job_reference.job_id
          # build up map of study matches by facet & filter value (for adding labels in UI)
          @studies_by_facet = self.class.match_studies_by_facet(query_results, @facets)
          # uniquify result list as one study may match multiple facets/filters
          @convention_accessions = query_results.map {|match| match[:study_accession]}.uniq
          Rails.logger.info "Found #{@convention_accessions.count} matching studies from BQ job #{job_id}: #{@convention_accessions}"
          @studies = @studies.where(:accession.in => @convention_accessions).order_by {|study| @studies_by_facet[study.accession][:facet_search_weight]}
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
          response 500 do
            key :description, 'Server error'
          end
        end
      end

      def facet_filters
        # sanitize query string for regexp matching
        @query_string = params[:query]
        query_matcher = /#{Regexp.escape(@query_string)}/i
        @matching_filters = @search_facet.filters.select {|filter| filter[:name] =~ query_matcher}
      end

      swagger_path '/search/auth_code' do
        operation :post do
          key :tags, [
              'Search'
          ]
          key :summary, 'Create One-time Auth Code for downloads'
          key :description, 'Create and return a One-Time Authorization Code to identify a user for bulk downloads'
          key :operationId, 'search_auth_code_path'
          response 200 do
            key :description, 'One-time auth code and time interval, in seconds'
            schema do
              property :totat do
                key :type, :integer
                key :description, 'One-time auth code'
              end
              property :ti do
                key :type, :integer
                key :description, 'Time interval (in seconds) otac will be valid'
              end
            end
          end
          response 401 do
            key :description, 'User is not signed in'
          end
          response 406 do
            key :description, 'Accept or Content-Type headers missing or misconfigured'
          end
        end
      end

      def create_auth_code
        half_hour = 1800 # seconds
        otac_and_ti = current_api_user.create_totat(half_hour)
        render json: otac_and_ti
      end

      swagger_path '/search/bulk_download' do
        operation :get do
          key :tags, [
              'Search'
          ]
          key :summary, 'Bulk download study data'
          key :description, 'Download files in bulk of multiple types from one or more studies via curl'
          key :operationId, 'search_bulk_download_path'
          parameter do
            key :name, :auth_code
            key :type, :integer
            key :in, :query
            key :description, 'User-specific one-time authorization code'
            key :required, true
          end
          parameter do
            key :name, :accessions
            key :type, :string
            key :in, :query
            key :description, 'Comma-delimited list of Study accessions'
            key :required, true
          end
          parameter do
            key :name, :file_types
            key :type, :string
            key :in, :query
            key :description, "Comma-delimited list of file types (including 'all' for all files)"
            key :required, true
          end
          response 200 do
            key :description, 'Curl configuration file with signed URLs for requested data'
            key :type, :string
          end
          response 400 do
            key :description, 'Invalid study accessions or requested file types'
          end
          response 401 do
            key :description, 'User not signed in'
          end
          response 403 do
            key :description, 'Invalid auth token, or requested download exceeds user download quota'
            schema do
              key :title, 'Error'
              property :message do
                key :type, :string
                key :description, 'Error message'
              end
            end
          end
          response 406 do
            key :description, 'Accept or Content-Type headers missing or misconfigured'
          end
        end
      end

      def bulk_download
        totat = params[:auth_code]
        valid_totat = User.verify_totat(totat)
        accessions = params[:accessions].split(',').map(&:strip)
        file_types = params[:file_types].split(',').map(&:strip)

        # sanitize study accessions and file types
        sanitized_accessions = StudyAccession.sanitize_accessions(accessions)
        sanitized_file_types = StudyFile::BULK_DOWNLOAD_TYPES & file_types # find array intersection

        # validate request parameters
        if totat.blank? || valid_totat == false
          render json: {error: 'Invalid authorization token'}, status: 403 and return
        elsif sanitized_accessions.blank? || sanitized_file_types.blank?
          render json: {error: 'Invalid request parameters; study accessions or file types not found'}, status: 400 and return
        end

        # load the user from the auth token
        requested_user = valid_totat

        # replace 'Expression' with both dense & sparse matrix file types
        if sanitized_file_types.include?('Expression')
          sanitized_file_types.delete_if {|file_type| file_type == 'Expression'}
          sanitized_file_types += ['Expression Matrix', 'MM Coordinate Matrix']
        end

        # get requested files
        files_requested = Study.where(:accession.in => sanitized_accessions).map {
            |study| study.study_files.by_type(sanitized_file_types)
        }.flatten

        # determine quota impact
        download_quota = ApplicationController.get_download_quota
        bytes_requested = files_requested.map(&:upload_file_size).reduce(:+)
        user_bytes_allowed = requested_user.daily_download_quota + bytes_requested
        if user_bytes_allowed > download_quota
          render json: {error: 'Requested total file size exceeds user download quota'}, status: 403 and return
        end

        logger.info "Beginning creation of curl configuration for user_id, auth token: #{requested_user.id}, #{totat}"
        curl_configs = ['--create-dirs', '--compressed']
        start_time = Time.zone.now

        # Get signed URLs for all files in the requested download objects, and update user quota
        Parallel.map(files_requested, in_threads: 100) do |study_file|
          client = FireCloudClient.new
          curl_configs << self.class.get_curl_config(file: study_file, fc_client: client)
          # send along any bundled files along with the parent
          if study_file.is_bundle_parent?
            study_file.bundled_files.each do |bundled_file|
              curl_configs << self.class.get_curl_config(file: bundled_file, fc_client: client)
            end
          end
        end
        requested_user.update(daily_download_quota: bytes_requested)

        # log results
        end_time = Time.zone.now
        runtime = TimeDifference.between(start_time, end_time).humanize
        logger.info "Curl configs generated for studies #{sanitized_accessions}, #{files_requested.size} total files"
        logger.info "Total time in generating curl configuration: #{runtime}"

        # send configuration file
        @configuration = curl_configs.join("\n\n")
        send_data @configuration, type: 'text/plain', filename: 'cfg.txt'
      end

      private

      def set_search_facet
        @search_facet = SearchFacet.find_by(identifier: params[:facet])
      end

      def set_search_facets_and_filters
        @facets = []
        if params[:facets].present?
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
      # array-based columns need to set up data in WITH clauses to allow for a single UNNEST(column_name) call,
      # otherwise UNNEST() is called multiple times for each user-supplied filter value and could impact performance
      def self.generate_bq_query_string(facets)
        base_query = "SELECT DISTINCT study_accession"
        from_clause = " FROM #{CellMetadatum::BIGQUERY_TABLE}"
        where_clauses = []
        with_clauses = []
        facets.each do |facet_obj|
          # get the facet instance in order to run query
          search_facet = SearchFacet.find(facet_obj[:object_id])
          column_name = search_facet.big_query_id_column
          if search_facet.is_array_based?
            # if facet is array-based, we need to format an array of filter values selected by user
            # and add this as a WITH clause, then add two UNNEST() calls for both the BQ array column
            # and the user filters to optimize the query
            # example query:
            # WITH disease_filters AS (SELECT['MONDO_0000001', 'MONDO_0006052'] as disease_value)
            # FROM cell_metadata.alexandria_convention, disease_filters, UNNEST(disease_filters.disease_value) AS disease_val
            # WHERE (disease_val IN UNNEST(disease))
            facet_id = search_facet.identifier
            filter_arr_name = "#{facet_id}_filters"
            filter_val_name = "#{facet_id}_value"
            filter_where_val = "#{facet_id}_val"
            filter_values = facet_obj[:filters].map {|filter| filter[:id]}
            with_clauses << "#{filter_arr_name} AS (SELECT#{filter_values} as #{filter_val_name})"
            from_clause += ", #{filter_arr_name}, UNNEST(#{filter_arr_name}.#{filter_val_name}) AS #{filter_where_val}"
            where_clauses << "(#{filter_where_val} IN UNNEST(#{column_name}))"
            base_query += ", #{filter_where_val}"
          else
            base_query += ", #{column_name}"
            # for non-array columns we can pass an array of quoted values and call IN directly
            filter_values = facet_obj[:filters].map {|filter| filter[:id]}
            where_clauses << "#{column_name} IN ('#{filter_values.join('\',\'')}')"
          end
        end
        # prepend WITH clauses before base_query, then add FROM and dependent WHERE clauses
        # all facets are treated as AND clauses
        "WITH #{with_clauses.join(", ")} " + base_query + from_clause + " WHERE " + where_clauses.join(" AND ")
      end

      # build a match of studies to facets/filters used in search (for labeling studies in UI with matches)
      def self.match_studies_by_facet(query_results, search_facets)
        matches = {}
        query_results.each do |result|
          accession = result[:study_accession]
          matches[accession] ||= {}
          search_weight = 0
          result.keys.keep_if { |key| key != :study_accession }.each do |key|
            facet_name = key.to_s.chomp('_val')
            matching_facet = search_facets.detect { |facet| facet[:id] == facet_name }
            matching_filter = matching_facet[:filters].detect { |filter| filter[:id] == result[key] }
            if facet_name != key.to_s
              # results with a key ending in _val are array based, and may have multiple matches, so append to existing list
              matches[accession][facet_name] ||= []
              matches[accession][facet_name] << matching_filter
            else
              # for non-array columns, still store as an array for consistent rendering in the UI
              matches[accession][facet_name] = [matching_filter]
            end
            search_weight += 1
          end
          # compute a score for relevance weighting
          matches[accession][:facet_search_weight] = search_weight
        end
        matches
      end

      # Helper method for generating a curl command to download a file from a bucket.  Returns file's curl config, size.
      def self.get_curl_config(file:, fc_client: )

        fc_client ||= Study.firecloud_client
        # if a file is a StudyFile, use bucket_location, otherwise the :name key will contain its location (if DirectoryListing)
        file_location = file.bucket_location
        study = file.study
        output_path = file.bulk_download_pathname

        begin
          signed_url = fc_client.execute_gcloud_method(:generate_signed_url, 0, study.bucket_id, file_location,
                                                       expires: 1.day.to_i) # 1 day in seconds, 86400
          curl_config = [
              'url="' + signed_url + '"',
              'output="' + output_path + '"'
          ]
        rescue => e
          error_context = ErrorTracker.format_extra_context(study, file)
          ErrorTracker.report_exception(e, current_user, error_context)
          logger.error "Error generating signed url for #{output_path}; #{e.message}"
          curl_config = [
              '# Error downloading ' + output_path + '.  ' +
                  'Did you delete the file in the bucket and not sync it in Single Cell Portal?'
          ]
        end

        curl_config.join("\n")
      end
    end
  end
end
