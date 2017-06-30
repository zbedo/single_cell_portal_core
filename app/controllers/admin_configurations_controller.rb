class AdminConfigurationsController < ApplicationController
  before_action :set_admin_configuration, only: [:show, :edit, :update, :destroy]
  before_filter do
    authenticate_user!
    authenticate_admin
  end

  # GET /admin_configurations
  # GET /admin_configurations.json
  def index
    @admin_configurations = AdminConfiguration.not_in(config_type: AdminConfiguration::FIRECLOUD_ACCESS_NAME)
    @current_firecloud_status = AdminConfiguration.current_firecloud_access
    case @current_firecloud_status
      when 'on'
        @download_status = true
        @download_status_label = "<span class='label label-success'><i class='fa fa-check'></i> Enabled</span>".html_safe
      when 'readonly'
        @download_status = true
        @download_status_label = "<span class='label label-warning'><i class='fa fa-exclamation-circle'></i> Read Only</span>".html_safe
      when 'off'
        @download_status = false
        @download_status_label = "<span class='label label-danger'><i class='fa fa-times'></i> Disabled</span>".html_safe
    end
  end

  # GET /admin_configurations/1
  # GET /admin_configurations/1.json
  def show
  end

  # GET /admin_configurations/new
  def new
    @admin_configuration = AdminConfiguration.new
  end

  # GET /admin_configurations/1/edit
  def edit
  end

  # POST /admin_configurations
  # POST /admin_configurations.json
  def create
    @admin_configuration = AdminConfiguration.new(admin_configuration_params)
    respond_to do |format|
      if @admin_configuration.save
        format.html { redirect_to admin_configurations_path, notice: "Configuration option '#{@admin_configuration.config_type}' was successfully created." }
        format.json { render :show, status: :created, location: @admin_configuration }
      else
        format.html { render :new }
        format.json { render json: @admin_configuration.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /admin_configurations/1
  # PATCH/PUT /admin_configurations/1.json
  def update
    respond_to do |format|
      if @admin_configuration.update(admin_configuration_params)
        format.html { redirect_to admin_configurations_path, notice: "Configuration option '#{@admin_configuration.config_type}' was successfully updated." }
        format.json { render :show, status: :ok, location: @admin_configuration }
      else
        format.html { render :edit }
        format.json { render json: @admin_configuration.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /admin_configurations/1
  # DELETE /admin_configurations/1.json
  def destroy
    @admin_configuration.destroy
    respond_to do |format|
      format.html { redirect_to admin_configurations_path, notice: "Configuration option '#{@admin_configuration.config_type}' was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  # disable/enable all downloads by revoking workspace ACLs
  def manage_firecloud_access
    @config = AdminConfiguration.find_or_create_by(config_type: AdminConfiguration::FIRECLOUD_ACCESS_NAME)
    # make sure that the value type has been set if just created
    @config.value_type ||= 'String'
    status = params[:firecloud_access][:status].downcase
    begin
      case status
        when 'on'
          AdminConfiguration.enable_firecloud_access
          @config.update(value: status)
          redirect_to admin_configurations_path, alert: "FireCloud access setting recorded successfully as 'on'."
        when 'off'
          AdminConfiguration.configure_firecloud_access('off')
          @config.update(value: status)
          redirect_to admin_configurations_path, alert: "FireCloud access setting recorded successfully as 'off'.  Portal study & workspace access is now disabled."
        when 'readonly'
          AdminConfiguration.configure_firecloud_access('readonly')
          @config.update(value: status)
          redirect_to admin_configurations_path, alert: "FireCloud access setting recorded successfully as 'readonly'.  Downloads are still enabled, but portal study access and workspace computes are disabled."
        else
          # do nothing, protect against bad status parameters
          nil
          redirect_to admin_configuration_path, alert: 'Invalid configuration option; ignored.'
      end
    rescue RuntimeError => e
      logger.error "#{Time.now}: error in setting download status to #{status}; #{e.message}"
      redirect_to admin_configuration_path, alert: "An error occured while turing #{status} downloads: #{e.message}" and return
    end
  end

  # reset user download quotas ahead of daily reset
  def reset_user_download_quotas
    User.update_all(daily_download_quota: 0)
  end

  # restart all orphaned jobs to allow them to continue
  def restart_locked_jobs
    jobs_restarted = AdminConfiguration.restart_locked_jobs
    if jobs_restarted > 0
      @message = "All locked jobs have successfully been restarted (#{jobs_restarted} total)."
    else
      @message = 'No orphaned jobs were found.'
    end
  end

  private
  # Use callbacks to share common setup or constraints between actions.
  def set_admin_configuration
    @admin_configuration = AdminConfiguration.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def admin_configuration_params
    params.require(:admin_configuration).permit(:config_type, :value_type, :value, :multiplier)
  end
end
