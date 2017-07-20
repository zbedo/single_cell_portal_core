class UserAnnotationsController < ApplicationController
  before_action :set_user_annotation, only: [:show, :edit, :update, :destroy]

  # GET /user_annotations
  # GET /user_annotations.json
  def index
    @user_annotations = UserAnnotation.all
  end

  # GET /user_annotations/1
  # GET /user_annotations/1.json
  def show
  end


  # GET /user_annotations/1/edit
  def edit

  end

  # PATCH/PUT /user_annotations/1
  # PATCH/PUT /user_annotations/1.json
  def update
    respond_to do |format|
      if @user_annotation.update(user_annotation_params)
        format.html { redirect_to @user_annotation, notice: 'User annotation was successfully updated.' }
        format.json { render :show, status: :ok, location: @user_annotation }
      else
        format.html { render :edit }
        format.json { render json: @user_annotation.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /user_annotations/1
  # DELETE /user_annotations/1.json
  def destroy
    @user_annotation.destroy
    respond_to do |format|
      format.html { redirect_to user_annotations_url, notice: 'User annotation was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
  # Use callbacks to share common setup or constraints between actions.
  def set_user_annotation
    @user_annotation = UserAnnotation.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  # whitelist parameters for creating custom user annotation
  def user_annotation_params
    params.require(:user_annotation).permit(:_id, :name, :study_id, :user_id, :cluster_group_id,  user_data_arrays_attributes: [:name, :values, :subsample_threshold, :subsample_annotation])
  end
end
