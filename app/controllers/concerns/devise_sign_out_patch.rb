module DeviseSignOutPatch
  extend ActiveSupport::Concern

  included do
    # DELETE /resource/sign_out
    def destroy
      # invalidate token
      current_user.update(authentication_token: nil, refresh_token: nil, access_token: nil, api_access_token: nil)
      signed_out = (Devise.sign_out_all_scopes ? sign_out : sign_out(resource_name))
      set_flash_message! :notice, :signed_out if signed_out
      yield if block_given?
      respond_to_on_destroy
    end
  end

end

Devise::SessionsController.send(:include, DeviseSignOutPatch)