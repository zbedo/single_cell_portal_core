module Api
  module V1
    class StatusController < ApiBaseController
      include Swagger::Blocks

      respond_to :json

      swagger_path '/recaptcha' do
        operation :get do
          key :tags, [
              'Metrics'
          ]
          key :summary, 'API Recaptcha Endpoint'
          key :description, 'Recaptcha response from Google indicating whether user is bot or not'
          response 200 do
            key :description, 'API is functioning normally'
          end
        end
      end

      def index
        head 200
      end
    end
  end
end
