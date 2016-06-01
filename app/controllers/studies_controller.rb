class StudiesController < ApplicationController
  before_action :set_study, only: [:show, :edit, :update, :destroy, :upload, :do_upload, :resume_upload, :update_status, :reset_upload, :new_study_file, :update_study_file, :delete_study_file, :retrieve_upload, :parse_study_files, :launch_parse_job]
  before_filter :authenticate_user!

  # GET /studies
  # GET /studies.json
  def index
    @studies = Study.editable(current_user).to_a
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
        format.json { render :show, status: :ok, location: @study }
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

  # load all study files available to be parsed
  def parse_study_files
    # load files needed for parsing
    @parseable = {
        :assignment => @study.study_files.select {|sf| sf.file_type == 'Cluster Assignments'},
        :points => @study.study_files.select {|sf| sf.file_type == 'Cluster Coordinates' && !sf.parsed},
        :expression => @study.study_files.select {|sf| sf.file_type == 'Expression Matrix' && !sf.parsed},
        :markers => @study.study_files.select {|sf| sf.file_type == 'Marker Gene List' && sf.upload_content_type == 'text/plain' && !sf.parsed}
    }

    # quick assignments to know which forms to render
    @can_parse = {
        :clusters => !@parseable[:assignment].empty? && !@parseable[:points].empty?,
        :expression => !@parseable[:expression].empty?,
        :markers => !@parseable[:markers].empty?
    }

  end

  # launches parse job via delayed_job and
  def launch_parse_job
    render nothing: true
  end

  # upload study files to study
  def upload
    @study_files = @study.study_files
  end

  # create a new study_file for requested study
  def new_study_file
    @study_file = @study.study_files.build
  end

  # update an existing study file; cannot be called until file is uploaded, so there is no create
  def update_study_file
    @study_file = StudyFile.where(study_id: study_file_params[:study_id], upload_file_name: study_file_params[:name]).first
    @study_file.update_attributes(study_file_params)
    @message = "'#{@study_file.name}' has been successfully updated."
  end

  # delete the requested study file
  def delete_study_file
    @study_file = StudyFile.find(params[:study_file_id])
    unless @study_file.nil?
      @message = "'#{@study_file.name}' has been successfully deleted."
      @study_file.destroy
    end
  end

  # method to perform chunked uploading of data
  def do_upload
    upload = get_upload
    filename = upload.original_filename
    study_file = @study.study_files.select {|sf| sf.upload_file_name == filename}.first
    # If no file has been uploaded or the uploaded file has a different filename,
    # do a new upload from scratch
    if study_file.nil?
      study_file = @study.study_files.build
      study_file.update_attributes(study_file_params)
      render json: study_file.to_jq_upload and return

      # If the already uploaded file has the same filename, try to resume
    else
      current_size = study_file.upload_file_size
      content_range = request.headers['CONTENT-RANGE']
      begin_of_chunk = content_range[/\ (.*?)-/,1].to_i # "bytes 100-999999/1973660678" will return '100'

      # If the there is a mismatch between the size of the incomplete upload and the content-range in the
      # headers, then it's the wrong chunk!
      # In this case, start the upload from scratch
      unless begin_of_chunk == current_size
        render json: study_file.to_jq_upload and return
      end
      # Add the following chunk to the incomplete upload
      File.open(study_file.upload.path, "ab") { |f| f.write(upload.read) }

      # Update the upload_file_size attribute
      study_file.upload_file_size = study_file.upload_file_size.nil? ? upload.size : study_file.upload_file_size + upload.size
      study_file.save!

      render json: study_file.to_jq_upload and return
    end
  end

  # GET /courses/:id/reset_upload
  def reset_upload
    # Allow users to delete uploads only if they are incomplete
    study_file = StudyFile.where(study_id: params[:id], name: params[:file]).first
    raise StandardError, "Action not allowed" unless study_file.status == 'uploading'
    study_file.update!(status: 'new', upload: nil)
    redirect_to upload_study_path(@study._id), notice: "Upload reset successfully. You can now start over"
  end

  # GET /courses/:id/resume_upload.json
  def resume_upload
    study_file = StudyFile.where(study_id: params[:id], name: params[:file]).first
    unless study_file.nil?
      render json: { file: { name: study_file.upload.url, size: study_file.upload_file_size } } and return
    else
      render json: { file: { name: "/uploads/default/missing.png",size: nil } } and return
    end
  end

  # PATCH /courses/:id/update_upload_status
  def update_status
    study_file = StudyFile.where(study_id: params[:id], name: params[:file]).first
    raise ArgumentError, "Wrong status provided " + params[:status] unless study_file.status == 'uploading' && params[:status] == 'uploaded'
    study_file.update!(status: params[:status])
    head :ok
  end

  # retrieve study file by filename
  def retrieve_upload
    @study_file = StudyFile.where(study_id: params[:id], upload_file_name: params[:file]).first
  end

  # method to download files if study is private
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

  # study params whitelist
  def study_params
    params.require(:study).permit(:name, :description, :public, :user_id, :embargo, study_files_attributes: [:id, :_destroy, :name, :path, :upload, :description, :file_type, :status], study_shares_attributes: [:id, :_destroy, :email, :permission])
  end

  # study file params whitelist
  def study_file_params
    params.require(:study_file).permit(:_id, :study_id, :name, :upload, :description, :file_type, :status, :downloadable)
  end

  # return upload object from study params
  def get_upload
    study_file_params.to_h['upload']
  end
end
