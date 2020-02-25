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
      ##

      # HTTP 401 - User is not signed in
      def self.unauthorized
        'User is not authenticated'
      end

      # HTTP 403 - User is not forbidden from performing action
      def self.forbidden(message)
        "User unauthorized to #{message}"
      end

      # HTTP 404 - Resource not found
      def self.not_found(*resources)
        "#{resources.join(', ')} not found"
      end

      # HTTP 406 - invalid response content type requested
      def self.not_acceptable
        'Only Accept: application/json header allowed'
      end

      # HTTP 410 - Resource gone (this only happens when a Study workspace has been deleted
      def self.resource_gone
        'Study workspace is not found, cannot complete action'
      end

      # HTTP 422 - Unprocessable entity; failed validation
      def self.unprocessable_entity(entity)
        "#{entity} validation failed"
      end
    end
  end
end
