module Api
  module V1
    class ApiBaseController < ActionController::API
      include Concerns::Authenticator
      include Concerns::ContentType
      include ActionController::MimeResponds
    end
  end
end