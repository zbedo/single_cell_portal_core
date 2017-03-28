class AdminConfigurationsController < ApplicationController
  before_action :set_admin_configuration, only: [:show, :edit, :update, :destroy]
  before_filter do
    authenticate_user!
    authenticate_admin
  end

  # GET /admin_configurations
  # GET /admin_configurations.json
  def index
    @admin_configurations = AdminConfiguration.all
    status_config = AdminConfiguration.find_by(config_type: AdminConfiguration::GLOBAL_DOWNLOAD_STATUS_NAME)
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
        format.html { redirect_to admin_configurations_path, notice: "Config option #{@admin_configuration.config_type} was successfully created." }
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
        format.html { redirect_to admin_configurations_path, notice: "Config option #{@admin_configuration.config_type} was successfully updated." }
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
      format.html { redirect_to admin_configurations_path, notice: "Config option #{@admin_configuration.config_type} was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  def manage_data_downloads
    @config = AdminConfiguration.find_or_create_by(config_type: AdminConfiguration::GLOBAL_DOWNLOAD_STATUS_NAME)
    @config.update(value: params[:status])
    redirect_to admin_configurations_path, alert: 'Data downloads setting recorded successfully.'
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
