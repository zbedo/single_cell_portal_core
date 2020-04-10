module Api
  module V1
    class MetadataSchemasController < ApiBaseController
      include Swagger::Blocks
      before_action :set_available_schemas, only: :index
      before_action :set_schema_filename, only: :load_schema
      before_action :set_schema_filepath, only: :load_schema
      before_action :set_response_type, only: :load_schema

      SCHEMAS_BASE_DIR = Rails.root.join('lib', 'assets', 'metadata_schemas')

      swagger_path '/metadata_schemas' do
        operation :get do
          key :tags, [
              'MetadataSchemas'
          ]
          key :summary, 'List all available metadata schemas'
          key :description, 'Returns a list of all available metadata schemas, by project & version'
          key :operationId, 'metadata_schemas_path'
          response 200 do
            key :description, 'list of available metadata convention schemas'
          end
        end
      end

      def index
        render json: @schemas
      end

      swagger_path '/metadata_schemas/{project_name}/{version}/{schema_format}' do
        operation :get do
          key :tags, [
              'MetadataSchemas'
          ]
          key :summary, 'Load a metadata convention schema file'
          key :description, 'Returns a schema definition file for the requested metadata convention, in JSON or TSV format'
          key :operationId, 'metadata_schemas_load_schema_path'
          parameter do
            key :name, :project_name
            key :in, :path
            key :description, 'Project name of metadata convention'
            key :required, true
            key :enum, %w(alexandria_convention)
            key :type, :string
          end
          parameter do
            key :name, :version
            key :in, :path
            key :description, 'Version of requested convention'
            key :required, true
            key :enum, %w(latest 2.0.0 1.1.5 1.1.4 1.1.3)
            key :type, :string
          end
          parameter do
            key :name, :schema_format
            key :in, :path
            key :description, 'File format of convention schema, either JSON or TSV'
            key :required, true
            key :enum, %w(json tsv)
            key :type, :string
          end
          response 200 do
            key :description, 'Metadata convention schema file in requested format'
          end
          response 404 do
            key :description, ApiBaseController.not_found('Convention Metadata Schema')
          end
          response 500 do
            key :description, 'Server error'
          end
        end
      end

      def load_schema
        if File.exists?(@schema_pathname)
          send_file @schema_pathname, type: @response_type, filename: @schema_filename
        else
          head 404 and return
        end
      end

      private

      def set_available_schemas
        @schemas = {}
        projects = Dir.entries(SCHEMAS_BASE_DIR).delete_if {|entry| entry.start_with?('.')}
        projects.each do |project_name|
          snapshots_path = SCHEMAS_BASE_DIR + "#{project_name}/snapshot"
          snapshots = Dir.entries(snapshots_path).delete_if {|entry| entry.start_with?('.')}
          versions = %w(latest) + Naturally.sort(snapshots).reverse
          @schemas[project_name] = versions
        end
      end

      def set_schema_filename
        project_name = params[:project_name]
        schema_format = params[:schema_format]
        @schema_filename = "#{project_name}_schema.#{schema_format}"
      end

      def set_schema_filepath
        project_name = params[:project_name]
        schema_version = params[:version]
        @schema_pathname = SCHEMAS_BASE_DIR + project_name
        if schema_version != 'latest'
          @schema_pathname += "snapshots/#{params[:version]}"
        end
        @schema_pathname += @schema_filename
        @schema_pathname
      end

      def set_response_type
        schema_format = params[:schema_format]
        case schema_format
        when 'json'
          @response_type = 'application/json'
        when 'tsv'
          @response_type = 'text/plain'
        else
          @response_type = 'application/json'
        end
      end
    end
  end
end

