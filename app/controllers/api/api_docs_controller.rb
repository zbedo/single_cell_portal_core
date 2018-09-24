module Api
  class ApiDocsController < ActionController::Base
    include Swagger::Blocks

    respond_to :json

    swagger_root do
      key :swagger, '2.0'
      info do
        key :version, 'v1'
        key :title, 'Single Cell Portal REST API'
        key :description, 'REST API Documentation for the Single Cell Portal'
        contact do
          key :name, 'Single Cell Portal Team'
          key :email, 'single_cell_portal@broadinstitute.org'
        end
        license do
          key :name, 'BSD-3-Clause'
          key :url, 'http://opensource.org/licenses/BSD-3-Clause'
        end
      end
      key :host, "#{ENV['HOSTNAME']}"
      key :basePath, '/single_cell/api'
      key :consumes, ['application/json']
      key :produces, ['application/json']
      security_definition :google_oauth2 do
        key :type, :oauth2
        key :authorizationUrl, "https://accounts.google.com/o/oauth2/auth"
        key :flow, :implicit
        scopes do
          key 'https://www.googleapis.com/auth/userinfo.email', 'email authorization'
          key 'https://www.googleapis.com/auth/userinfo.profile', 'profile authorization'
          key 'https://www.googleapis.com/auth/cloud-billing.readonly', 'read-only access to billing accounts'
          key 'https://www.googleapis.com/auth/devstorage.read_only', 'read-only access to GCS storage objects'
        end
      end
      security do
        key :google_oauth2, %w(https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/userinfo.profile
                               https://www.googleapis.com/auth/cloud-billing.readonly https://www.googleapis.com/auth/devstorage.read_only)
      end
    end

    SWAGGERED_CLASSES = [
        self,
        Api::V1::StudiesController
    ].freeze

    def index
      render json: Swagger::Blocks.build_root_json(SWAGGERED_CLASSES)
    end
  end
end
