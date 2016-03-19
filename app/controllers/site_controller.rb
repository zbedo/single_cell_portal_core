class SiteController < ApplicationController

  before_action :set_study, except: :index
  before_action :set_clusters, except: :index

  # view study overviews and downloads
  def index
    @studies = Study.order('name ASC')
    @downloads = {}
    @studies.each do |study|
      if study.study_files.any?
        @downloads[study.url_safe_name] = study.study_files.sort_by(&:name)
      end
    end
  end

  # load single study and view top-level clusters
  def study
    # parse all coordinates out into hash using generic method
    load_cluster_points
    @num_points = @coordinates.values.map {|v| v[:text].size}.inject {|sum, x| sum + x}
  end

  # render a single cluster and its constituent sub-clusters
  def render_cluster
    load_cluster_points
  end

  # search for one or more genes to view expression information
  def search_genes
    terms = params[:search][:genes].split.map(&:chomp)
    @genes = ExpressionScore.where(:gene.in => terms).to_a

    if @genes.empty?
      redirect_to request.referrer, alert: "No matches found for: #{terms.join(', ')}"
    elsif @genes.size > 1
      redirect_to request.referrer
    else
      gene = @genes.first
      # determine whether to show all sub-clusters grouped by parent, or an individual sub-cluster
      if !params[:search][:cluster].blank?
        redirect_to view_gene_expression_path(study_name: params[:study_name], gene: gene.gene, cluster: params[:search][:cluster])
      else
        redirect_to view_gene_expression_path(study_name: params[:study_name], gene: gene.gene)
      end
    end
  end

  # render box and scatter plots for parent clusters or a particular sub cluster
  def view_gene_expression
    @gene = ExpressionScore.where(gene: params[:gene]).first
    load_expression_scores
    load_cluster_points
    # load cluster plot, but use expression scores to set numerical color array
    @expression = {}
    @annotations = []
    @expression[:all] = {x: [], y: [], text: [], name: 'Gene Expression', marker: {cmax: 0, cmin: 0, color: [], showscale: true, autoscale: true}}
    @clusters.each do |cluster|
      points = cluster.cluster_points
      points.each do |point|
        @expression[:all][:text] << point.single_cell.name
        @expression[:all][:x] << point.x
        @expression[:all][:y] << point.y
        # load in expression score to use as color value
        @expression[:all][:marker][:color] << @gene.scores[point.single_cell.name].to_f
      end
        # calculate median postition for cluster labels
        x_postions = cluster.cluster_points.map(&:x).sort
        y_postions = cluster.cluster_points.map(&:y).sort
        x_len = x_postions.size
        y_len = y_postions.size
        @annotations << {
          x: (x_postions[(x_len - 1) / 2] + x_postions[x_len / 2]) / 2.0,
          y: (y_postions[(y_len - 1) / 2] + y_postions[y_len / 2]) / 2.0,
          xref: 'x',
          yref: 'y',
          text: cluster.name,
          showarrow: false,
          borderpad: 4,
          bgcolor: '#efefef',
          bordercolor: '#ccc',
          borderwidth: 1,
          opacity: 0.65
        }
    end
    color_minmax =  @expression[:all][:marker][:color].minmax
    @expression[:all][:marker][:cmin], @expression[:all][:marker][:cmax] = color_minmax
    @expression[:all][:marker][:colorscale] = [ [ color_minmax.first, "#dcdcdc" ],  [ color_minmax.last, "#b2a01c" ] ]
    @options = [""]
    @study.clusters.parent_clusters.each do |cluster|
      unless @study.clusters.sub_cluster(cluster.name).empty?
        @options << cluster.name
      end
    end
  end

  private

  # generic method to populate data structure to render a cluster scatterplot
  def load_cluster_points
    @coordinates = {}
    @clusters.each do |cluster|
      @coordinates[cluster.name] = {x: [], y: [], text: [], name: cluster.name}
      points = cluster.cluster_points
      points.each do |point|
        @coordinates[cluster.name][:text] << point.single_cell.name
        @coordinates[cluster.name][:x] << point.x
        @coordinates[cluster.name][:y] << point.y
      end
    end
  end

  # generic method to populate data structure to render a box plot
  def load_expression_scores
    @values = {}
    @clusters.each do |cluster|
      @values[cluster.name] = {y: [], name: cluster.name }
      # grab all cells present in the cluster, and use as keys to load expression scores
      # if a cell is not present, score gets set as 0.0
      cluster.single_cells.map(&:name).each do |cell|
        @values[cluster.name][:y] << @gene.scores[cell].to_f
      end
    end
  end

  # set the current study
  def set_study
    @study = Study.where(url_safe_name: params[:study_name]).first
  end

  # return clusters, depending on whether top- or sub-level clusters are requested
  def set_clusters
    @clusters = params[:cluster] ? @study.clusters.sub_cluster(params[:cluster]) : @study.clusters.parent_clusters
    @clusters.sort_by!(&:name)
  end
end
