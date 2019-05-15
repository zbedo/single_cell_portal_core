module Api
  module V1
    module Concerns
      module Authenticator
        extend ActiveSupport::Concern

        def authenticate_api_user!
          head 401 unless api_user_signed_in?
        end

        def set_current_api_user!
          current_api_user
        end

        def api_user_signed_in?
          current_api_user.present?
        end

        # method to authenticate a user via Authorization Bearer tokens
        def current_api_user
          api_access_token = extract_bearer_token(request)
          if api_access_token.present?
            user = User.find_by('api_access_token.access_token' => api_access_token)
            if user.nil?
              # extract user info from access_token
              begin
                token_url = "https://www.googleapis.com/oauth2/v1/tokeninfo?access_token=#{api_access_token}"
                response = RestClient.get token_url
                credentials = JSON.parse response.body
                token_values = {
                    'access_token' => api_access_token,
                    'expires_in' => credentials['expires_in'],
                    'expires_at' => Time.zone.now + credentials['expires_in'].to_i
                }
                email = credentials['email']
                user = User.find_by(email: email)
                if user.present?
                  # store api_access_token to speed up retrieval next time
                  user.update(api_access_token: token_values)
                else
                  Rails.logger.error "Unable to retrieve user info from access token: #{api_access_token}"
                end
              rescue => e
                error_context = {
                    auth_response_body: response.present? ? response.body : nil,
                    auth_response_code: response.present? ? response.code : nil,
                    auth_response_headers: response.present? ? response.headers : nil
                }
                ErrorTracker.report_exception(e, user, error_context)
                Rails.logger.error "Error retrieving user api credentials: #{e.class.name}: #{e.message}"
              end
            end
            # check for token expiry and unset user if expired
            if user.api_access_token_expired?
              nil
            else
              user
            end
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

