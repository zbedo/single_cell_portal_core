module Api
  module V1
    class StudyFilesController < ApiBaseController

      include Concerns::FireCloudStatus

      before_action :set_study
      before_action :check_study_permission
      before_action :set_study_file, except: [:index, :create, :bundle]

      respond_to :json

      # GET /single_cell/api/v1/studies/:study_id
      def index
        @study_files = @study.study_files.where(queued_for_deletion: false)
      end

      # GET /single_cell/api/v1/studies/:study_id/study_files/:id
      def show

      end

      # POST /single_cell/api/v1/studies/:study_id/study_files
      def create
        @study_file = @study.study_files.build(study_file_params)

        if @study_file.save
          @study.delay.send_to_firecloud(@study_file)
          render :show
        else
          render json: {errors: @study_file.errors}, status: :unprocessable_entity
        end
      end

      # PATCH /single_cell/api/v1/studies/:study_id/study_files/:id
      def update
        if @study_file.update(study_file_params)
          if ['Cluster', 'Coordinate Labels', 'Gene List'].include?(@study_file.file_type) && @study_file.valid?
            @study_file.invalidate_cache_by_file_type
          end
          # if a gene list or cluster got updated, we need to update the associated records
          if study_file_params[:file_type] == 'Gene List'
            @precomputed_entry = PrecomputedScore.find_by(study_file_id: study_file_params[:_id])
            @precomputed_entry.update(name: @study_file.name)
          elsif study_file_params[:file_type] == 'Cluster'
            @cluster = ClusterGroup.find_by(study_file_id: study_file_params[:_id])
            @cluster.update(name: @study_file.name)
            # also update data_arrays
            @cluster.data_arrays.update_all(cluster_name: @study_file.name)
          elsif ['Expression Matrix', 'MM Coordinate Matrix'].include?(study_file_params[:file_type]) && !study_file_params[:y_axis_label].blank?
            # if user is supplying an expression axis label, update default options hash
            @study.update(default_options: @study.default_options.merge(expression_label: study_file_params[:y_axis_label]))
            @study.expression_matrix_files.first.invalidate_cache_by_file_type
          end
          render :show
        else
          render json: {errors: @study_file.errors}, status: :unprocessable_entity
        end
      end

      # DELETE /single_cell/api/v1/studies/:study_id/study_files/:id
      def destroy
        human_data = @study_file.human_data # store this reference for later
        # delete matching caches
        @study_file.invalidate_cache_by_file_type
        # queue for deletion
        @study_file.update(queued_for_deletion: true)
        DeleteQueueJob.new(@study_file).delay.perform
        begin
          # make sure file is in FireCloud first
          unless human_data || @study_file.generation.blank?
            present = Study.firecloud_client.execute_gcloud_method(:get_workspace_file, @study.firecloud_project,
                                                                   @study.firecloud_workspace, @study_file.upload_file_name)
            if present
              Study.firecloud_client.execute_gcloud_method(:delete_workspace_file, @study.firecloud_project,
                                                           @study.firecloud_workspace, @study_file.upload_file_name)
            end
          end
          head 204
        rescue RuntimeError => e
          logger.error "#{Time.now}: error in deleting #{@study_file.upload_file_name} from workspace: #{@study.firecloud_workspace}; #{e.message}"
          render json: {error: "Error deleting remote file in bucket: #{e.message}"}, status: 500
        end
      end

      # POST /single_cell/api/v1/studies/:study_id/study_files/bundle
      # Create a StudyFileBundle from a list of files
      def bundle
        # must convert to an unsafe hash re: https://github.com/rails/rails/pull/28734
        unsafe_params = params.to_unsafe_hash
        file_params = unsafe_params[:files]
        if file_params.present?
          @study_file_bundle = StudyFileBundle.new(original_file_list: file_params, study_id: params[:study_id])
          if @study_file_bundle.save
            render 'api/v1/study_file_bundles/show'
          else
            render json: @study_file_bundle.errors, status: :unprocessable_entity
          end
        else
          render json: {error: "Malformed request: payload must be formatted as {files: [{name: 'filename', file_type: 'file_type'}]}"},
                 status: :bad_request
        end
      end

      private

      def set_study
        @study = Study.find_by(id: params[:study_id])
        if @study.nil? || @study.queued_for_deletion?
          head 404 and return
        end
      end

      def set_study_file
        @study_file = StudyFile.find_by(id: params[:id])
        if @study_file.nil? || @study_file.queued_for_deletion?
          head 404 and return
        end
      end

      def check_study_permission
        head 403 unless @study.can_edit?(current_api_user)
      end

      # study file params whitelist
      def study_file_params
        params.require(:study_file).permit(:_id, :study_id, :name, :upload, :upload_file_name, :upload_content_type, :upload_file_size,
                                           :remote_location, :description, :file_type, :status, :human_fastq_url, :human_data, :cluster_type,
                                           :generation, :x_axis_label, :y_axis_label, :z_axis_label, :x_axis_min, :x_axis_max, :y_axis_min,
                                           :y_axis_max, :z_axis_min, :z_axis_max,
                                           options: [:cluster_group_id, :font_family, :font_size, :font_color, :matrix_id, :submission_id,
                                                     :bam_id, :analysis_name, :visualization_name])
      end
    end
  end
end

