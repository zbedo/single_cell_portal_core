module Api
  module V1
    class DirectoryListingsController < ApiBaseController

      before_action :set_study
      before_action :check_study_permission
      before_action :set_directory_listing, except: [:index, :create]

      respond_to :json

      # GET /single_cell/api/v1/studies/:study_id
      def index
        @directory_listings = @study.directory_listings
      end

      # GET /single_cell/api/v1/studies/:study_id/directory_listings/:id
      def show
      end

      # POST /single_cell/api/v1/studies/:study_id/directory_listings
      def create
        @directory_listing = @study.directory_listings.build(directory_listing_params)

        if @directory_listing.save
          # set sync_status to true if directory saved, unless this was manually set
          set_sync_status
          render :show
        else
          render json: {errors: @directory_listing.errors}, status: :unprocessable_entity
        end
      end

      # PATCH /single_cell/api/v1/studies/:study_id/directory_listings/:id
      def update
        if @directory_listing.update(directory_listing_params)
          # set sync_status to true if directory saved, unless this was manually set
          set_sync_status
          render :show
        else
          render json: {errors: @directory_listing.errors}, status: :unprocessable_entity
        end
      end

      # DELETE /single_cell/api/v1/studies/:study_id/directory_listings/:id
      def destroy
        begin
          @directory_listing.destroy
          head 204
        rescue => e
          render json: {error: e.message}, status: 500
        end
      end

      private

      def set_study
        @study = Study.find_by(id: params[:study_id])
        if @study.nil? || @study.queued_for_deletion?
          head 404 and return
        end
      end

      def set_directory_listing
        @directory_listing = DirectoryListing.find_by(id: params[:id])
        if @directory_listing.nil?
          head 404 and return
        end
      end

      def check_study_permission
        head 403 unless @study.can_edit?(current_api_user)
      end

      # study file params whitelist
      def directory_listing_params
        params.require(:directory_listing).permit(:id, :name, :description, :file_type, :sync_status, files: [:name, :size, :generation])
      end

      # check sync_status on directory create/update, will default to true unless manually set to false
      def set_sync_status
        sync_status = ActiveModel::Type::Boolean.new.cast(directory_listing_params[:sync_status])
        if sync_status.nil?
          @directory_listing.update(sync_status: true)
        else
          @directory_listing.update(sync_status: sync_status)
        end
      end
    end
  end
end

