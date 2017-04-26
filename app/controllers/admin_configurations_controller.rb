class AdminConfigurationsController < ApplicationController
  before_action :set_admin_configuration, only: [:show, :edit, :update, :destroy]
  before_filter do
    authenticate_user!
    authenticate_admin
  end

  # GET /admin_configurations
  # GET /admin_configurations.json
  def index
    @admin_configurations = AdminConfiguration.not_in(config_type: AdminConfiguration::GLOBAL_DOWNLOAD_STATUS_NAME)
    status_config = AdminConfiguration.download_status_config
    if status_config.nil? || (!status_config.nil? && status_config.value == 'on')
      @download_status = true
      @download_status_label = "<span class='label label-success'><i class='fa fa-check'></i> Enabled</span>".html_safe
    else
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
  def manage_data_downloads
    @config = AdminConfiguration.find_or_create_by(config_type: AdminConfiguration::GLOBAL_DOWNLOAD_STATUS_NAME)
    # make sure that the value type has been set if just created
    @config.value_type ||= 'String'
    status = params[:status].downcase
    begin
      case status
        when 'on'
          AdminConfiguration.enable_all_downloads
          @config.update(value: status)
          redirect_to admin_configurations_path, alert: "Data downloads setting recorded successfully as 'on'."
        when 'off'
          AdminConfiguration.disable_all_downloads
          @config.update(value: status)
          redirect_to admin_configurations_path, alert: "Data downloads setting recorded successfully as 'off'.  User study access & downloads are now disabled."
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
