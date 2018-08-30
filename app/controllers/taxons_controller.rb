class TaxonsController < ApplicationController
  before_action :set_taxon, except: [:index, :new, :create]
  before_action do
    authenticate_user!
    authenticate_admin
  end

  # GET /taxons
  # GET /taxons.json
  def index
    @taxons = Taxon.all
  end

  # GET /taxons/1
  # GET /taxons/1.json
  def show
  end

  # GET /taxons/new
  def new
    @taxon = Taxon.new
  end

  # GET /taxons/1/edit
  def edit
  end

  # POST /taxons
  # POST /taxons.json
  def create
    @taxon = Taxon.new(taxon_params)

    respond_to do |format|
      if @taxon.save
        format.html { redirect_to taxon_path(@taxon), notice: "Species: '#{@taxon.display_name}' was successfully created." }
        format.json { render :show, status: :created, location: @taxon }
      else
        format.html { render :new }
        format.json { render json: @taxon.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /taxons/1
  # PATCH/PUT /taxons/1.json
  def update
    respond_to do |format|
      if @taxon.update(taxon_params)
        format.html { redirect_to taxons_path, notice: "Species: '#{@taxon.display_name}' was successfully updated." }
        format.json { render :show, status: :ok, location: @taxon }
      else
        format.html { render :edit }
        format.json { render json: @taxon.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /taxons/1
  # DELETE /taxons/1.json
  def destroy
    display_name = @taxon.display_name
    @taxon.destroy
    respond_to do |format|
      format.html { redirect_to taxons_path, notice: "Species: '#{display_name}' was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  def download_genome_annotation
    begin
      reference_workspace = AdminConfiguration.find_by(config_type: 'Reference Data Workspace')
      ref_namespace, ref_workspace = reference_workspace.value.split('/')
      annotation_link = Study.firecloud_client.generate_signed_url(ref_namespace, ref_workspace,
                                                                   @taxon.genome_annotation_link, expires: 15)
      redirect_to annotation_link and return
    rescue => e
      redirect_to taxons_path, alert: "Unable to load genome annotation for #{@taxon.display_name}: #{e.message}" and return
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_taxon
      @taxon = Taxon.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def taxon_params
      params.require(:taxon).permit(:common_name, :scientific_name, :taxon_id, :genome_assembly, :genome_assembly_alias,
                                    :genome_annotation, :genome_annotation_link, :aliases => [])
    end
end
