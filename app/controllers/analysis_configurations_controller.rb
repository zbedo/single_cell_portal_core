class AnalysisConfigurationsController < ApplicationController
  before_action :set_analysis_configuration, only: [:show, :edit, :update, :destroy]
  before_action do
    authenticate_user!
    authenticate_admin
  end


  # GET /analysis_configurations
  # GET /analysis_configurations.json
  def index
    @analysis_configurations = AnalysisConfiguration.all
  end

  # GET /analysis_configurations/1
  # GET /analysis_configurations/1.json
  def show
  end

  # GET /analysis_configurations/new
  def new
    @analysis_configuration = AnalysisConfiguration.new
  end

  # GET /analysis_configurations/1/edit
  def edit
  end

  # POST /analysis_configurations
  # POST /analysis_configurations.json
  def create
    @analysis_configuration = AnalysisConfiguration.new(analysis_configuration_params)

    respond_to do |format|
      if @analysis_configuration.save
        format.html { redirect_to @analysis_configuration, notice: 'Analysis configuration was successfully created.' }
        format.json { render :show, status: :created, location: @analysis_configuration }
      else
        format.html { render :new }
        format.json { render json: @analysis_configuration.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /analysis_configurations/1
  # PATCH/PUT /analysis_configurations/1.json
  def update
    respond_to do |format|
      if @analysis_configuration.update(analysis_configuration_params)
        format.html { redirect_to @analysis_configuration, notice: 'Analysis configuration was successfully updated.' }
        format.json { render :show, status: :ok, location: @analysis_configuration }
      else
        format.html { render :edit }
        format.json { render json: @analysis_configuration.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /analysis_configurations/1
  # DELETE /analysis_configurations/1.json
  def destroy
    @analysis_configuration.destroy
    respond_to do |format|
      format.html { redirect_to analysis_configurations_url, notice: 'Analysis configuration was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_analysis_configuration
      @analysis_configuration = AnalysisConfiguration.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def analysis_configuration_params
      params.require(:analysis_configuration).permit(:namespace, :name, :snapshot, :user_id, analysis_parameters_attributes: [
          :id, :data_type, :call_name, :parameter_type, :parameter_name, :parameter_value, :optional, :_destroy
      ])
    end
end
