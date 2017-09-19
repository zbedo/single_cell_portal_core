class ExpressionScoreController < ApplicationController

  ###
  #
  # This controller is only used for the autocomplete funcitonality in the gene search panel
  #
  ###

  before_action :set_expression_score, only: [:show]
  autocomplete :expression_score, :gene

  def index
    @expression_scores = ExpressionScore.all
  end

  def show
  end

  def get_autocomplete_items(parameters)
    all_expression_scores = mongoid_get_autocomplete_items(parameters)
    expression_scores = all_expression_scores.where(:study_id => params[:study_id]).to_a.uniq{|e| e.gene}
    expression_scores
  end

  private

  def set_expression_score
    @expression_score = ExpressionScore.find(params[:id])
  end
end

