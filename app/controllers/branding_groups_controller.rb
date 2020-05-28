class BrandingGroupsController < ApplicationController
  before_action :set_branding_group, only: [:show, :edit, :update, :destroy]
  before_action do
    authenticate_user!
    authenticate_admin
  end

  # GET /branding_groups
  # GET /branding_groups.json
  def index
    @branding_groups = BrandingGroup.all
  end

  # GET /branding_groups/1
  # GET /branding_groups/1.json
  def show
  end

  # GET /branding_groups/new
  def new
    @branding_group = BrandingGroup.new
  end

  # GET /branding_groups/1/edit
  def edit
  end

  # POST /branding_groups
  # POST /branding_groups.json
  def create
    @branding_group = BrandingGroup.new(branding_group_params)

    respond_to do |format|
      if @branding_group.save
        # push all branding assets to remote to ensure consistency
        UserAssetService.delay.push_assets_to_remote(asset_path: :branding_images)
        format.html { redirect_to merge_default_redirect_params(branding_group_path(@branding_group), scpbr: params[:scpbr]),
                                  notice: "Branding group '#{@branding_group.name}' was successfully created." }
        format.json { render :show, status: :created, location: @branding_group }
      else
        format.html { render :new }
        format.json { render json: @branding_group.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /branding_groups/1
  # PATCH/PUT /branding_groups/1.json
  def update
    respond_to do |format|
      if @branding_group.update(branding_group_params)
        format.html { redirect_to merge_default_redirect_params(branding_group_path(@branding_group), scpbr: params[:scpbr]),
                                  notice: "Branding group '#{@branding_group.name}' was successfully updated." }
        format.json { render :show, status: :ok, location: @branding_group }
      else
        format.html { render :edit }
        format.json { render json: @branding_group.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /branding_groups/1
  # DELETE /branding_groups/1.json
  def destroy
    name = @branding_group.name
    @branding_group.destroy
    respond_to do |format|
      format.html { redirect_to merge_default_redirect_params(branding_groups_path, scpbr: params[:scpbr]),
                                notice: "Branding group '#{name}' was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_branding_group
    @branding_group = BrandingGroup.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def branding_group_params
    params.require(:branding_group).permit(:name, :tag_line, :background_color, :font_family, :font_color, :user_id,
                                           :splash_image, :banner_image, :footer_image)
  end
end
