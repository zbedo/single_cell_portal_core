class SiteController < ApplicationController

  before_action :set_study, except: :index
  before_action :set_clusters, except: :index

  COLORSCALE_THEMES = ['Blackbody', 'Bluered', 'Blues', 'Earth', 'Electric', 'Greens', 'Hot', 'Jet', 'Picnic', 'Portland', 'Rainbow', 'RdBu', 'Reds', 'Viridis', 'YlGnBu', 'YlOrRd']

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
    terms = parse_search_terms(:genes)
    @genes = ExpressionScore.where(:study_id => @study._id, :searchable_gene.in => terms).to_a
    # grab saved params for loaded cluster and boxpoints mode
    cluster = params[:search][:cluster]
    boxpoints = params[:search][:boxpoints]
    if @genes.empty?
      redirect_to request.referrer, alert: "No matches found for: #{terms.join(', ')}"
    elsif @genes.size > 1
      if !cluster.blank?
        redirect_to view_gene_expression_heatmap_path(search: {genes: terms.join(' ')}, cluster: cluster)
      else
        redirect_to view_gene_expression_heatmap_path(search: {genes: terms.join(' ')})
      end
    else
      gene = @genes.first
      # determine whether to show all sub-clusters grouped by parent, or an individual sub-cluster
      if !cluster.blank?
        redirect_to view_gene_expression_path(study_name: params[:study_name], gene: gene.gene, cluster: cluster, boxpoints: boxpoints)
      else
        redirect_to view_gene_expression_path(study_name: params[:study_name], gene: gene.gene, boxpoints: boxpoints)
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
    @expression[:all] = {x: [], y: [], text: [], marker: {cmax: 0, cmin: 0, color: [], showscale: true, colorbar: {title: 'log(TPM) Expression Values', titleside: 'right'}}}
    @clusters.each do |cluster|
      points = cluster.cluster_points
      points.each do |point|
        @expression[:all][:text] << "<b>#{point.single_cell.name}</b> [#{cluster.name}]<br>log(TPM) expression: #{@gene.scores[point.single_cell.name].to_f}".html_safe
        @expression[:all][:x] << point.x
        @expression[:all][:y] << point.y
        # load in expression score to use as color value
        @expression[:all][:marker][:color] << @gene.scores[point.single_cell.name].to_f
      end
        # calculate median position for cluster labels
        x_postions = cluster.cluster_points.map(&:x).sort
        y_postions = cluster.cluster_points.map(&:y).sort
        x_len = x_postions.size
        y_len = y_postions.size
        x_pos = (x_postions[(x_len - 1) / 2] + x_postions[x_len / 2]) / 2.0
        y_pos = (y_postions[(y_len - 1) / 2] + y_postions[y_len / 2]) / 2.0
        @annotations << {
          x: x_pos,
          y: y_pos,
          xref: 'x',
          yref: 'y',
          text: cluster.name,
          showarrow: false,
          borderpad: 4,
          bgcolor: '#efefef',
          bordercolor: '#ccc',
          borderwidth: 1,
          opacity: 0.6
        }
    end
    color_minmax =  @expression[:all][:marker][:color].minmax
    @expression[:all][:marker][:cmin], @expression[:all][:marker][:cmax] = color_minmax
    @expression[:all][:marker][:colorscale] = 'Reds'
    @options = load_sub_cluster_options
  end

  def view_gene_expression_heatmap
    terms = parse_search_terms(:genes)
    @genes = ExpressionScore.where(:study_id => @study._id, :searchable_gene.in => terms).to_a.sort_by {|g| g.gene}
    load_heatmap_scores
    @options = load_sub_cluster_options
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
      # if a cell is not present for the gene, score gets set as 0.0
      cluster.single_cells.map(&:name).each do |cell|
        @values[cluster.name][:y] << @gene.scores[cell].to_f
      end
    end
  end

  # generic method to populate data structure to render a heatmap
  def load_heatmap_scores
    genes = @genes.map(&:gene).sort.reverse
    @values = {x: [], y: genes, z: [], text: [], type: 'heatmap', colorscale: 'Reds'}
    # for each gene & cell, grab expression value
    # if a cell is not present for the gene, score gets set as 0.0
    @genes.reverse_each do |gene|
      scores = []
      text = []
      @clusters.each do |cluster|
        cluster.single_cells.each do |cell|
          @values[:x] << cell.name
          score = gene.scores[cell.name].to_f
          scores << score
          text << "<b>#{cell.name}</b> [#{cluster.name}]<br><em>#{gene.gene}</em> log(TMP) expression: #{score}"
        end
      end
      @values[:z] << scores
      @values[:text] << text
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

  # generic search term parser
  def parse_search_terms(key)
    params[:search][key].split.map {|gene| gene.chomp.downcase}.sort
  end

  # generic method to assemble options for sub-cluster dropdown
  def load_sub_cluster_options
    opts = [["Major cell types",""]]
    @study.clusters.parent_clusters.each do |cluster|
      unless @study.clusters.sub_cluster(cluster.name).empty?
        opts << cluster.name
      end
    end
    opts
  end
end
