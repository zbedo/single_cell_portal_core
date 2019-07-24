module Api
  module V1
    class ApiBaseController < ActionController::API
      include Concerns::ContentType
      include Concerns::CspHeaderBypass
      include ActionController::MimeResponds
      extend ErrorTracker

      rescue_from ActionController::ParameterMissing do |exception|
        render json: {error: exception.message}, status: 400
      end

      rescue_from NoMethodError, Faraday::ConnectionFailed do |exception|
        render json: {error: exception.message}, status: 500
      end

      ##
      # Generic message formatters to use in Swagger responses
      # TODO: Extend to 401/403/404
      ##

      # handle a 410 response message (both in UI and API) - this only happens when a Study workspace has been deleted
      def self.resource_gone
        'Study workspace is not found, cannot complete action'
      end
    end
  end
end