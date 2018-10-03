module Api
  module V1
    module Concerns
      module Authenticator
        extend ActiveSupport::Concern

        included do
          before_action :authenticate_api_user!, unless: proc { %w(schemas taxons).include?(controller_name)}
        end

        def authenticate_api_user!
          head 401 unless api_user_signed_in?
        end

        def api_user_signed_in?
          current_api_user.present?
        end

        # method to authenticate a user via Authorization Bearer tokens
        def current_api_user
          api_access_token = extract_bearer_token(request)
          if api_access_token.present?
            user = User.find_by(api_access_token: api_access_token)
            if user.nil?
              # extract user info from access_token
              begin
                token_url = "https://www.googleapis.com/oauth2/v1/tokeninfo?access_token=#{api_access_token}"
                response = RestClient.get token_url
                credentials = JSON.parse response.body
                email = credentials['email']
                user = User.find_by(email: email)
                if user.present?
                  # store api_access_token to speed up retrieval next time
                  user.update(api_access_token: api_access_token)
                else
                  Rails.logger.error "Unable to retrieve user info from access token: #{api_access_token}"
                end
              rescue => e
                Rails.logger.error "Error retrieving user api credentials: #{e.class.name}: #{e.message}"
              end
            end
            user
          end
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

