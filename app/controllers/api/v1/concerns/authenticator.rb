module Api
  module V1
    module Concerns
      module Authenticator
        extend ActiveSupport::Concern

        included do
          before_action :authenticate_api_user!
        end

        def authenticate_api_user!
          head 401 unless api_user_signed_in?
        end

        def api_user_signed_in?
          current_api_user.present?
        end

        # method to authenticate a user via Authorization Bearer tokens
        def current_api_user
          @current_api_user = nil
          api_access_token = extract_bearer_token(request)
          if api_access_token.present?
            @current_api_user = User.find_by(api_access_token: api_access_token)
            if @current_api_user.nil?
              # extract user info from access_token
              begin
                token_url = "https://www.googleapis.com/oauth2/v1/tokeninfo?access_token=#{api_access_token}"
                response = RestClient.get token_url
                credentials = JSON.parse response.body
                email = credentials['email']
                @current_api_user = User.find_by(email: email)
                # store api_access_token to speed up retrieval next time
                @current_api_user.update(api_access_token: api_access_token)
              rescue => e
                Rails.logger.error "Error retrieving user api credentials: #{e.message}"
              end
            end
          end
          @current_api_user
        end

        private

        # attempt to extract the Authorization Bearer token
        def extract_bearer_token(request)
          if request.headers['Authorization'].present?
            token = request.headers['Authorization'].split.last
            token.gsub!(/(\'|\")/, '')
            token
          end
        end
      end
    end
  end
end

