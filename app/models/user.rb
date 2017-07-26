require 'rest-client'

class User
  include Mongoid::Document
  include Mongoid::Timestamps

  has_many :studies

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,
         :omniauthable, :omniauth_providers => [:google_oauth2]

  validates_format_of :email,:with => Devise.email_regexp

  ## Database authenticatable
  field :email,              type: String, default: ""
  field :encrypted_password, type: String, default: ""

  ## Recoverable
  field :reset_password_token,   type: String
  field :reset_password_sent_at, type: Time

  ## Rememberable
  field :remember_created_at, type: Time

  ## Trackable
  field :sign_in_count,      type: Integer, default: 0
  field :current_sign_in_at, type: Time
  field :last_sign_in_at,    type: Time
  field :current_sign_in_ip, type: String
  field :last_sign_in_ip,    type: String

  ## OmniAuth
  field :uid,       type: String
  field :provider,  type: String

  # token auth for AJAX calls
  field :authentication_token, type: String

  # Google OAuth refresh token fields
  field :refresh_token, type: String
  field :access_token, type: Hash

  ## Confirmable
  # field :confirmation_token,   type: String
  # field :confirmed_at,         type: Time
  # field :confirmation_sent_at, type: Time
  # field :unconfirmed_email,    type: String # Only if using reconfirmable

  ## Lockable
  # field :failed_attempts, type: Integer, default: 0 # Only if lock strategy is :failed_attempts
  # field :unlock_token,    type: String # Only if unlock strategy is :email or :both
  # field :locked_at,       type: Time

  ## Custom
  field :admin, type: Boolean
  field :reporter, type: Boolean
  field :daily_download_quota, type: Integer, default: 0

  def self.from_omniauth(access_token)
    data = access_token.info
    provider = access_token.provider
    uid = access_token.uid
    # create bogus password, Devise will never use it to authenticate
    password = Devise.friendly_token[0,20]
    user = User.find_by(email: data['email'])
    if user.nil?
      user = User.create(email: data["email"],
                         password: password,
                         password_confirmation: password,
                         uid: uid,
                         provider: provider)
    # update info if account was originally local but switching to Google auth
    elsif user.provider.nil? || user.uid.nil?
      user.update(provider: provider, uid: uid)
    end
    # store refresh token
    if !access_token.credentials.refresh_token.nil?
      user.update(refresh_token: access_token.credentials.refresh_token)
    end
    user
  end

  # generate an access token based on user's refresh token
  def generate_access_token
    unless self.refresh_token.nil?
      begin
        response = RestClient.post 'https://accounts.google.com/o/oauth2/token',
                                   :grant_type => 'refresh_token',
                                   :refresh_token => self.refresh_token,
                                   :client_id => ENV['OAUTH_CLIENT_ID'],
                                   :client_secret => ENV['OAUTH_CLIENT_SECRET']
        token_vals = JSON.parse(response.body)
        expires_at = DateTime.now + token_vals['expires_in'].to_i.seconds
        user_access_token = {'access_token' => token_vals['access_token'], 'expires_in' => token_vals['expires_in'], 'expires_at' => expires_at}
        self.update!(access_token: user_access_token)
        user_access_token
      rescue RestClient::BadRequest => e
        Rails.logger.error "#{Time.now}: Unable to generate access token for user #{self.email}; refresh token is invalid."
        nil
      rescue => e
        Rails.logger.error "#{Time.now}: Unable to generate access token for user #{self.email} due to unknown error; #{e.message}"
      end
    else
      nil
    end
  end

  # check timestamp on user access token expiry
  def access_token_expired?
    Time.at(self.access_token[:expires_at]) < Time.now # expired token, so we should quickly return
  end

  # return an valid access token (will renew if expired)
  def valid_access_token
    self.access_token_expired? ? self.generate_access_token : self.access_token
  end

  # determine if user has access to reports functionality
  def acts_like_reporter?
    self.admin? || self.reporter?
  end

  # user email address as a DOM id
  def email_as_id
    self.email.gsub(/[@\.]/, '-')
  end

  # helper method to migrate study ownership & shares from old email to new email
  def self.migrate_studies_and_shares(existing_email, new_email)
    existing_user = self.find_by(email: existing_email)
    new_user = self.find_by(email: new_email)
    studies = existing_user.studies
    shares = StudyShare.where(email: existing_email).to_a
    puts "Migrating #{studies.size} studies from #{existing_email} to #{new_email}"
    studies.update_all(user_id: new_user.id)
    puts "Migrating #{shares.size} shares from #{existing_email} to #{new_email}"
    shares.update_all(email: new_email)
    puts "Migration complete"
  end
end
