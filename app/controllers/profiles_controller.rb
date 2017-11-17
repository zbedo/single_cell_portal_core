class ProfilesController < ApplicationController

  ##
  #
  # ProfilesController: controller to allow users to manage certain aspects of their user account
  # since user accounts map to Google profiles, we cannot alter anything about the source profile
  #
  ##

  before_action :set_user
  before_filter do
    authenticate_user!
    check_access_settings
  end

  def show
    @study_shares = StudyShare.where(email: @user.email)
    @studies = Study.where(user_id: @user.id)
  end

  def update
    if @user.update(user_params)
      @notice = 'Admin email subscription update successfully recorded.'
    else
      @alert = "Unable to save admin email subscription settings: #{@user.errors.map(&:full_messages).join(', ')}"
    end
  end

  def update_study_subscription
    @study = Study.find(params[:study_id])
    update = study_params[:default_options][:deliver_emails] == 'true'
    opts = @study.default_options
    if @study.update(default_options: opts.merge(deliver_emails: update))
      @notice = 'Study email subscription update successfully recorded.'
    else
      @alert = "Unable to save study email subscription settings: #{@share.errors.map(&:full_messages).join(', ')}"
    end
  end

  def update_share_subscription
    @share = StudyShare.find(params[:study_share_id])
    update = study_share_params[:deliver_emails] == 'true'
    if @share.update(deliver_emails: update)
      @notice = 'Study email subscription update successfully recorded.'
    else
      @alert = "Unable to save study email subscription settings: #{@share.errors.map(&:full_messages).join(', ')}"
    end
  end

  private

  # set the requested user account
  def set_user
    @user = User.find(params[:id])
  end

  # make sure the current user is the same as the requested profile
  def check_access_settings
    if current_user.email != @user.email
      redirect_to site_path, alert: 'You do not have permission to perform that action.' and return
    end
  end

  def user_params
    params.require(:user).permit(:admin_email_delivery)
  end

  def study_share_params
    params.require(:study_share).permit(:deliver_emails)
  end

  def study_params
    params.require(:study).permit(:default_options => [:deliver_emails])
  end
end
