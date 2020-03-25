class PresetSearchesController < ApplicationController
  before_action :set_preset_search, only: [:show, :edit, :update, :destroy]
  before_action do
    authenticate_user!
    authenticate_admin
  end

  # GET /preset_searches
  # GET /preset_searches.json
  def index
    @preset_searches = PresetSearch.all
  end

  # GET /preset_searches/1
  # GET /preset_searches/1.json
  def show
  end

  # GET /preset_searches/new
  def new
    @preset_search = PresetSearch.new
  end

  # GET /preset_searches/1/edit
  def edit
  end

  # POST /preset_searches
  # POST /preset_searches.json
  def create
    @preset_search = PresetSearch.new(preset_search_params)

    respond_to do |format|
      if @preset_search.save
        format.html { redirect_to @preset_search, notice: 'Stored search was successfully created.' }
        format.json { render :show, status: :created, location: @preset_search }
      else
        format.html { render :new }
        format.json { render json: @preset_search.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /preset_searches/1
  # PATCH/PUT /preset_searches/1.json
  def update
    respond_to do |format|
      if @preset_search.update(preset_search_params)
        format.html { redirect_to @preset_search, notice: 'Stored search was successfully updated.' }
        format.json { render :show, status: :ok, location: @preset_search }
      else
        format.html { render :edit }
        format.json { render json: @preset_search.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /preset_searches/1
  # DELETE /preset_searches/1.json
  def destroy
    @preset_search.destroy
    respond_to do |format|
      format.html { redirect_to preset_searches_url, notice: 'Stored search was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_preset_search
      @preset_search = PresetSearch.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def preset_search_params
      params.require(:preset_search).permit(:name, :identifier, :accession_whitelist, :search_terms, :facet_filters, :public)
    end
end
