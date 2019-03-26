module Api
  module V1
    module Concerns
      module SiteAuthenticator
        extend ActiveSupport::Concern
        include CurrentApiUser

        included do
          before_action :set_current_api_user!
        end

        def set_current_api_user!
          api_user_signed_in? ? current_api_user : nil
        end

        def api_user_signed_in?
          current_api_user.present?
        end

      end
    end
  end
end

