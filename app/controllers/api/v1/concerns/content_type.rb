module Api
  module V1
    module Concerns
      module ContentType
        extend ActiveSupport::Concern

        included do
          before_action :validate_content_type!
        end

        # default to JSON responses, disallow other Accept content types or format requests
        # will allow Accept: */* and respond with JSON
        def validate_content_type!
          accept_header = request.headers['Accept'].present? ? request.headers['Accept'] : 'application/json'
          request_format = request.format.present? ? request.format : :json
          if !%w(*/* application/json).include?(accept_header) || request_format != :json
            head 406
          end
        end
      end
    end
  end
end
