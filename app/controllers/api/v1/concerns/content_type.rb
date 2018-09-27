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
          if request.headers['Content-Type'] =~ /multipart\/form-data/
            head 406 unless request.headers['Content-Length'].present? &&
                request.headers['Accept'] === 'application/json'
          else
            head 406 unless request.headers['Accept'] === 'application/json'
          end
        end
      end
    end
  end
end
