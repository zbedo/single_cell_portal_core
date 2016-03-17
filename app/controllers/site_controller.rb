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
    unless @clusters.empty?
      load_cluster_points
    else
      render 'cannot_render_cluster'
    end
  end

  def search_genes
    genes =
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
