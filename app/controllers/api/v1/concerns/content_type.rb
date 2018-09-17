module Api
  module V1
    module Concerns
      module ContentType
        extend ActiveSupport::Concern

        included do
          before_action :validate_content_type!
        end

        # force all requests to be application/json
        def validate_content_type!
          logger.info "content type: #{request.headers['Content-Type']}"
          if request.headers['Content-Type'] =~ /multipart\/form-data/
            head 406 unless request.headers['Content-Range'].present? &&
                request.headers['Accept'] === 'application/json'
          else
            head 406 unless ['application/x-www-form-urlencoded', 'application/json'].include?(request.headers['Content-Type']) &&
                request.headers['Accept'] === 'application/json'
          end

        end
      end
    end
  end
end
