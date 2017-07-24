class UserAnnotationsController < ApplicationController
  before_action :set_user_annotation, only: [:show, :edit, :update, :destroy]
  before_filter :authenticate_user!
  before_action :check_permission, except: :index
  # GET /user_annotations
  # GET /user_annotations.json
  def index
    @user_annotations = current_user.user_annotations.owned_by(current_user)
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
    new_labels = user_annotation_params.to_h['values']
    if @user_annotation.values.include? 'Undefined'
      new_labels.push('Undefined')
    end
    logger.info("new labels: #{new_labels}")
    old_labels = @user_annotation.values

    annotation_arrays = @user_annotation.user_data_arrays.where(array_type: 'annotations').to_a
    logger.info("#changed: #{annotation_arrays.length}")
    respond_to do |format|
      if @user_annotation.update(user_annotation_params)

        annotation_arrays.each do |annot|
          #Get the index of old labels, this is per annotation

          old_values = annot.values

          index_of_values = []
          old_labels.each_with_index do |old, i|
            index_array = []
            old_values.each_with_index do |value, i|
              if value == old
                index_array.push(i)
              end
            end
            index_of_values.push(index_array)
          end

          index_of_values.each_with_index do |old_index, i|
            logger.info("in loop, old index:  #{old_index}")
            old_index.each do |index|
              old_values[index] = new_labels[i]
            end
          end
          logger.info("new old values is: #{old_values}")
          annot.update(values: old_values, name: user_annotation_params.to_h['name'])

        end

        @user_annotation.user_data_arrays.to_a.each do |a|
          if !a.subsample_annotation.nil?
            a.update(subsample_annotation: user_annotation_params.to_h['name'] + '--group--user')
          end
        end
        format.html { redirect_to user_annotations_path, notice: "User Annotation '#{@user_annotation.name}' was successfully updated." }
        format.json { render :index, status: :ok, location: user_annotations_path }
      else
        format.html { render :edit }
        format.json { render json: @user_annotation.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /user_annotations/1
  # DELETE /user_annotations/1.json
  def destroy
    @user_annotation.user_data_arrays.destroy
    @user_annotation.destroy
    respond_to do |format|
      format.html { redirect_to user_annotations_path, notice: "User Annotation '#{@user_annotation.name}' was successfully destroyed." }
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
    params.require(:user_annotation).permit(:_id, :name, :study_id, :user_id, :cluster_group_id, values: [])
  end

  # checks that current user id is the same as annotation being edited or destroyed
  def check_permission
    if @user_annotation.user_id != current_user.id
      redirect_to user_annotations_path, alert: 'You don\'t have permission to perform that action'
    end
  end
end
