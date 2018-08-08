class GeneController < ApplicationController

  ###
  #
  # This controller is only used for the autocomplete funcitonality in the gene search panel
  #
  ###

  before_action :set_gene, only: [:show]
  autocomplete :gene, :name

  def index
    @genes = Gene.all
  end

  def show
  end

  def autocomplete_gene_name
    study_genes = Gene.where(study_id: params[:study_id])
    matching_genes = study_genes.any_of(
        {name: /#{params[:term]}/},
        {searchable_name: /#{params[:term].downcase}/},
        {gene_id: /#{params[:term]}/i}
    ).limit(10)
   render json: matching_genes.map {|gene| {id: gene.id, label: gene.autocomplete_label, value: gene.name}}
  end

  private

  def set_gene
    @gene = Gene.find(params[:id])
  end
end

