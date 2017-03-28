class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  DAILY_DOWNLOAD_LIMIT = 2.terabytes

  def authenticate_admin
    unless current_user.admin
      redirect_to site_path, alert: 'You do not have permission to access that page.' and return
    end
  end
end
