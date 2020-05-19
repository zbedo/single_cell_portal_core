class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController

  ###
  #
  # This is the OAuth2 endpoint for receiving callbacks from Google after successful authentication
  #
  ###



  # Merges unauth’d and auth’d user identities in Mixpanel via Bard
  #
  # Bard is a DSP service that mediates writes to Mixpanel. To enable tracking
  # users when they are signed in and not, Bard provides an endpoint
  # `/api/identify` to merge identities.  In SCP's case, the anonynmous ID
  # (`anonId`) is a random UUIDv4 string set as a cookie for all users --
  # auth'd or not -- upon visiting SCP.

  # This call links that anonId to the user's bearer token used by DSP's Sam
  # service.  That bearer token is in turn linked to a deidentified
  # "distinct ID" used to track users across auth states in Mixpanel.
  def self.merge_identities(user, cookies)

    # Skip merge_identities on production until Mixpanel is ready
    if Rails.env == 'production'
      return nil
    end

    Rails.logger.info "Merging user identity in Mixpanel via Bard"

    bard_host_url = Rails.application.config.bard_host_url

    bard_path = bard_host_url + '/api/identify'
    headers = {
      'Authorization' => "Bearer #{user.access_token['access_token']}",
      'Content-Type': 'application/json'
    }

    post_body = {'anonId': cookies['user_id']}.to_json

    params = {
      method: 'POST',
      url: bard_path,
      headers: headers,
      payload: post_body
    }

    begin
      response = RestClient::Request.execute(params)
    rescue RestClient::ExceptionWithResponse => e
      Rails.logger.error "Bard error in call to #{bard_path}: #{e.message}"
      # Rails.logger.error e.to_yaml
      ErrorTracker.report_exception(e, user, params)
    end

  end

  def google_oauth2
    # You need to implement the method below in your model (e.g. app/models/user.rb)
    @user = User.from_omniauth(request.env["omniauth.auth"])

    if @user.persisted?
      @user.update(authentication_token: Devise.friendly_token(32))
      @user.generate_access_token
      # update a user's FireCloud status
      @user.delay.update_firecloud_status
      sign_in(@user)
      if TosAcceptance.accepted?(@user)
        self.class.merge_identities(@user, cookies)
        redirect_to request.env['omniauth.origin'] || site_path
      else
        redirect_to accept_tos_path(@user.id)
      end
    else
      redirect_to new_user_session_path
    end
  end
end
