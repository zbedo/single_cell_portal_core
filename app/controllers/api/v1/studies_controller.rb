module Api
  module V1
    class StudiesController < ApiBaseController

      before_action :set_study, except: [:index, :create]
      before_action :check_study_permission, except: [:index, :create]
      before_action :check_firecloud_status, except: [:index, :show]

      # GET /single_cell/api/v1/studies
      def index
        @studies = Study.editable(current_api_user)
        render json: @studies.map(&:attributes)
      end

      # GET /single_cell/api/v1/studies/:id
      def show
        render json: @study.attributes
      end

      # POST /single_cell/api/v1/studies
      def create
        @study = Study.new(study_params)
        @study.user = current_api_user # automatically set user from credentials


        if @study.save
          render json: @study.attributes, status: :ok
        else
          render json: {errors: @study.errors}, status: :unprocessable_entity
        end
      end

      # PATCH /single_cell/api/v1/studies/:id
      def update
        if @study.update(study_params)
          if @study.previous_changes.keys.include?('name')
            # if user renames a study, invalidate all caches
            old_name = @study.previous_changes['url_safe_name'].first
            CacheRemovalJob.new(old_name).delay.perform
          end
          render json: @study.attributes, status: :ok
        else
          render json: {errors: @study.errors}, status: :unprocessable_entity
        end
      end

      # DELETE /single_cell/api/v1/studies/:id
      def destroy
        # check if user is allowed to delete study
        if @study.can_delete?(current_api_user)
          if params[:workspace] == 'persist'
            @study.update(firecloud_workspace: nil)
          else
            begin
              Study.firecloud_client.delete_workspace(@study.firecloud_project, @study.firecloud_workspace)
            rescue RuntimeError => e
              logger.error "#{Time.now} unable to delete workspace: #{@study.firecloud_workspace}; #{e.message}"
              render json: {error: "Error deleting FireCloud workspace #{@study.firecloud_project}/#{@study.firecloud_workspace}: #{e.message}"}, status: 500
            end
          end

          # set queued_for_deletion manually - gotcha due to race condition on page reloading and how quickly delayed_job can process jobs
          @study.update(queued_for_deletion: true)

          # queue jobs to delete study caches & study itself
          CacheRemovalJob.new(@study.url_safe_name).delay.perform
          DeleteQueueJob.new(@study).delay.perform

          # revoke all study_shares
          @study.study_shares.delete_all

          head 204
        else
          head 403
        end
      end

      private

      def set_study
        @study = Study.find_by(id: params[:id])
        if @study.nil? || @study.queued_for_deletion?
          head 404 and return
        end
      end

      def check_study_permission
        head 403 unless @study.can_edit?(current_api_user)
      end

      # study params whitelist
      def study_params
        params.require(:study).permit(:name, :description, :public, :embargo, :use_existing_workspace, :firecloud_workspace,
                                      :firecloud_project, :branding_group_id, study_shares_attributes: [:id, :_destroy, :email, :permission])
      end

      # check on FireCloud API status and respond accordingly
      def check_firecloud_status
        unless Study.firecloud_client.services_available?('Sam', 'Rawls')
          alert = 'Study workspaces are temporarily unavailable, so we cannot complete your request.  Please try again later.'
          render json: {error: alert}, status: 503
        end
      end
    end
  end
end

