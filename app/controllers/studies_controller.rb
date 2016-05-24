class StudiesController < ApplicationController
  before_action :set_study, only: [:show, :edit, :update, :destroy]
  before_filter :authenticate_user!

  # GET /studies
  # GET /studies.json
  def index
    @studies = Study.where(user_id: current_user.id).to_a
  end

  # GET /studies/1
  # GET /studies/1.json
  def show
  end

  # GET /studies/new
  def new
    @study = Study.new
  end

  # GET /studies/1/edit
  def edit
  end

  # POST /studies
  # POST /studies.json
  def create
    @study = Study.new(study_params)

    respond_to do |format|
      if @study.save
        format.html { redirect_to studies_path, notice: 'Study was successfully created.' }
        format.json { render :show, status: :created, location: @study }
      else
        format.html { render :new }
        format.json { render json: @study.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /studies/1
  # PATCH/PUT /studies/1.json
  def update
    respond_to do |format|
      if @study.update(study_params)
        format.html { redirect_to studies_path, notice: 'Study was successfully updated.' }
        format.json { render :show, status: :ok, location: @study }
      else
        format.html { render :edit }
        format.json { render json: @study.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /studies/1
  # DELETE /studies/1.json
  def destroy
    @study.destroy
    respond_to do |format|
      format.html { redirect_to studies_path, notice: 'Study was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  def download_private_file
    @study = Study.where(url_safe_name: params[:study_name]).first
    filepath = Rails.root.join('data', params[:study_name], params[:filename])
    if File.exist?(filepath) && @study.user_id == current_user._id
      send_file filepath,
                filename: params[:filename],
                disposition: 'attachment'

    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_study
      @study = Study.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def study_params
      params.require(:study).permit(:name, :description, :public, :user_id, study_files_attributes: [:id, :_destroy, :name, :path, :data, :description, :file_type])
    end
end
