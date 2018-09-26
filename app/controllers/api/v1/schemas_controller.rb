module Api
  module V1
    class SchemasController < ApiBaseController
      include Swagger::Blocks

      swagger_path '/schemas/studies' do
        operation :get do
          key :tags, [
              'Schemas'
          ]
          key :summary, 'Describe the Study schema'
          key :description, 'Returns a description of all Study attributes, with names/types/defaults'
          key :operationId, 'schemas_studies_path'
          response 200 do
            key :description, 'Description of Study schema'
          end
        end
      end

      def studies

      end

      swagger_path '/schemas/study_files' do
        operation :get do
          key :tags, [
              'Schemas'
          ]
          key :summary, 'Describe the StudyFile schema'
          key :description, 'Returns a description of all StudyFile attributes, with names/types/defaults'
          key :operationId, 'schemas_study_files_path'
          response 200 do
            key :description, 'Description of StudyFile schema'
          end
        end
      end

      def study_files

      end

      swagger_path '/schemas/study_file_bundles' do
        operation :get do
          key :tags, [
              'Schemas'
          ]
          key :summary, 'Describe the StudyFileBundle schema'
          key :description, 'Returns a description of all StudyFileBundle attributes, with names/types/defaults'
          key :operationId, 'schemas_study_file_bundles_path'
          response 200 do
            key :description, 'Description of StudyFileBundle schema'
          end
        end
      end

      def study_files

      end

      swagger_path '/schemas/study_shares' do
        operation :get do
          key :tags, [
              'Schemas'
          ]
          key :summary, 'Describe the StudyShare schema'
          key :description, 'Returns a description of all StudyShare attributes, with names/types/defaults'
          key :operationId, 'schemas_studies_path'
          response 200 do
            key :description, 'Description of StudyShare schema'
          end
        end
      end

      def study_shares

      end

      swagger_path '/schemas/directory_listings' do
        operation :get do
          key :tags, [
              'Schemas'
          ]
          key :summary, 'Describe the DirectoryListing schema'
          key :description, 'Returns a description of all Study attributes, with names/types/defaults'
          key :operationId, 'schemas_directory_listings_path'

          response 200 do
            key :description, 'Description of DirectoryListing schema'
          end
        end
      end

      def directory_listings

      end
    end
  end
end

