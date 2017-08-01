class UserAnnotationsController < ApplicationController
  before_action :set_user_annotation, only: [:edit, :update, :destroy]
  #Check that use is logged in in order to do anything
  before_filter :authenticate_user!
  before_action :check_permission, except: :index
  # GET /user_annotations
  # GET /user_annotations.json
  def index
    #get all this user's annotations
    @user_annotations = current_user.user_annotations.owned_by(current_user)
    views = UserAnnotation.viewable(current_user)
    edits = UserAnnotation.editable(current_user)
    @user_annotations.concat(views).concat(edits).uniq!
  end

  # GET /user_annotations/1/edit
  def edit

  end

  # PATCH/PUT /user_annotations/1
  # PATCH/PUT /user_annotations/1.json
  def update
    # check if any changes were made to sharing for notifications
    if !user_annotation_params[:user_annotation_shares_attributes].nil?
      @share_changes = @user_annotation.user_annotation_shares.count != user_annotation_params[:user_annotation_shares_attributes].keys.size
      user_annotation_params[:user_annotation_shares_attributes].values.each do |share|
        if share["_destroy"] == "1"
          @share_changes = true
        end
      end
    else
      @share_changes = false
    end
    #update the annotation's defined labels
    new_labels = user_annotation_params.to_h['values']
    #If the labels sued to include undefined, make sure they do again
    if @user_annotation.values.include? 'Undefined'
      new_labels.push('Undefined')
    end

    #Remeber the old values
    old_labels = @user_annotation.values

    #Remeber the old annotations
    annotation_arrays = @user_annotation.user_data_arrays.by_name_and_type(@user_annotation.name,'annotations')

    respond_to do |format|
      #if a successful update, update data arrays
      if @user_annotation.update(user_annotation_params)
        changes = []
        if @share_changes
          changes << 'Annotation shares'
        end
        if @user_annotation.user_annotation_shares.any?
          SingleCellMailer.annot_share_update_notification(@user_annotation, changes, current_user).deliver_now
        end
        #this is per annotation array-- each annotation array is a different subsampling level
        annotation_arrays.each do |annot|
          #remember the index of old labels, this is per annotation
          old_values = annot.values

          #remeber all the old indices and their labels
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

          #index of values remembers what the order of the old annotations was
          index_of_values.each_with_index do |old_index, i|
            old_index.each do |index|
              old_values[index] = new_labels[i]
            end
          end

          #update the annotations with new values
          annot.update(values: old_values, name: user_annotation_params.to_h['name'])

        end

        #Update the names of the user data arrays
        @user_annotation.user_data_arrays.to_a.each do |annot|
          if !annot.subsample_annotation.nil?
            annot.update(subsample_annotation: user_annotation_params.to_h['name'] + '--group--user')
          end
        end
        #If successful, redirect back and say success
        format.html { redirect_to user_annotations_path, notice: "User Annotation '#{@user_annotation.name}' was successfully updated." }
        format.json { render :index, status: :ok, location: user_annotations_path }
      else
        #If an error, show it
        format.html { render :edit }
        format.json { render json: @user_annotation.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /user_annotations/1
  # DELETE /user_annotations/1.json
  def destroy
    #delete data arrays when deleting an annotation
    @user_annotation.user_data_arrays.destroy
    @user_annotation.destroy
    respond_to do |format|
      #redirect back to page when destroy finishes
      format.html { redirect_to user_annotations_path, notice: "User Annotation '#{@user_annotation.name}' was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  def download_user_annotation
    cluster_name = @user_annotation.cluster_group.name
    filename = (cluster_name + '_' + @user_annotation.name + '.txt').gsub(/ /, '_')
    headers = ['NAME', 'X', 'Y', @user_annotation.name]
    types = ['TYPE', 'numeric', 'numeric', 'group']
    rows = []

    annotation_array = @user_annotation.user_data_arrays.where(array_type: 'annotations').first.values
    x_array = @user_annotation.user_data_arrays.where(array_type: 'coordinates', name: 'x').first.values
    y_array = @user_annotation.user_data_arrays.where(array_type: 'coordinates', name: 'y').first.values
    cell_name_array = @user_annotation.user_data_arrays.where(array_type: 'cells').first.values

    annotation_array.each_with_index do |annot, index|
      if annot != 'Undefined'
        row = []
        row << cell_name_array[index]
        row << x_array[index]
        row << y_array[index]
        row << annot
        rows << row.join("\t")
      end

    end
    @data = [headers.join("\t"), types.join("\t"), rows].join"\n"

    send_data @data, type: 'text/plain', filename: filename, disposition: 'attachment'
  end

  private
  # Use callbacks to share common setup or constraints between actions.
  def set_user_annotation
    @user_annotation = UserAnnotation.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  # whitelist parameters for creating custom user annotation
  def user_annotation_params
    params.require(:user_annotation).permit(:_id, :name, :study_id, :user_id, :cluster_group_id, values: [], user_annotation_shares_attributes: [:id, :_destroy, :email, :permission])
  end

  # checks that current user id is the same as annotation being edited or destroyed
  def check_permission
    if @user_annotation.nil?
      @user_annotation = UserAnnotation.find(params[:id])
    end
    if !@user_annotation.can_edit?(current_user)
      redirect_to user_annotations_path, alert: 'You don\'t have permission to perform that action'
    end
  end
end
