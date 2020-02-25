module Api
  module V1
    module Concerns
      module ContentType
        extend ActiveSupport::Concern

        included do
          before_action :validate_content_type!
        end

        # default to JSON responses, disallow other Accept header formats
        def validate_content_type!
          if request.headers['Accept'].present? && !%w(*/* application/json).include?(request.headers['Accept'])
            head 406
          end
        end
      end
    end
  end
end
