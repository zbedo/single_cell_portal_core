module Api
  module V1
    module Concerns
      module CspHeaderBypass
        extend ActiveSupport::Concern

        included do
          before_action :exclude_csp_headers!
        end

        # disable all CSP headers for API responses
        def exclude_csp_headers!
          SecureHeaders.opt_out_of_all_protection(request)
        end
      end
    end
  end
end
