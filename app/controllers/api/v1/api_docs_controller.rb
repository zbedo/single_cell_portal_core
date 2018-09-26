module Api
  module V1
    class ApiDocsController < ActionController::Base
      include Swagger::Blocks

      respond_to :json

      swagger_root do
        key :swagger, '2.0'
        info do
          key :version, 'v1'
          key :title, 'Single Cell Portal REST API'
          key :description, 'REST API Documentation for the Single Cell Portal'
          license do
            key :name, 'BSD-3-Clause'
            key :url, 'http://opensource.org/licenses/BSD-3-Clause'
          end
        end
        tag do
          key :name, 'Studies'
          key :description, 'Study operations'
        end
        tag do
          key :name, 'StudyFiles'
          key :description, 'StudyFile operations'
        end
        key :host, "#{ENV['HOSTNAME']}"
        key :basePath, '/single_cell/api/v1'
        key :consumes, ['application/json']
        key :produces, ['application/json']
        security_definition :google_oauth2 do
          key :type, :oauth2
          key :authorizationUrl, "https://accounts.google.com/o/oauth2/auth"
          key :flow, :implicit
          scopes do
            key 'https://www.googleapis.com/auth/userinfo.email', 'email authorization'
            key 'https://www.googleapis.com/auth/userinfo.profile', 'profile authorization'
          end
        end
        security do
          key :google_oauth2, %w(https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/userinfo.profile)
        end
      end

      SWAGGERED_CLASSES = [
          self,
          Study,
          StudyFile,
          DirectoryListing,
          StudyShare,
          Api::V1::StudiesController,
          Api::V1::StudyFilesController
      ].freeze

      def index
        render json: Swagger::Blocks.build_root_json(SWAGGERED_CLASSES)
      end
    end
  end
end
