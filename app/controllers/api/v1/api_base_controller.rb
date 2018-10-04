module Api
  module V1
    class ApiBaseController < ActionController::API
      include Concerns::Authenticator
      include Concerns::ContentType
      include Concerns::CspHeaderBypass
      include ActionController::MimeResponds

      rescue_from ActionController::ParameterMissing do |exception|
        render json: {error: exception.message}, status: 400
      end

      rescue_from NoMethodError, Faraday::ConnectionFailed do |exception|
        render json: {error: exception.message}, status: 500
      end
    end
  end
end