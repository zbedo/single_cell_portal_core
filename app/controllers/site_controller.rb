class SiteController < ApplicationController

  respond_to :html, :js, :json

  before_action :set_study, except: [:index, :search]
  before_action :load_precomputed_options, except: [:index, :search, :annotation_query, :download_file, :download_fastq_file]
  before_action :set_cluster_group, except: [:index, :search, :precomputed_results, :download_file, :download_fastq_file]
  before_action :set_selected_annotation, except: [:index, :search, :study, :precomputed_results, :expression_query, :get_new_annotations, :download_file, :download_fastq_file]
  before_action :check_view_permissions, except: [:index, :search]
  COLORSCALE_THEMES = ['Blackbody', 'Bluered', 'Blues', 'Earth', 'Electric', 'Greens', 'Hot', 'Jet', 'Picnic', 'Portland', 'Rainbow', 'RdBu', 'Reds', 'Viridis', 'YlGnBu', 'YlOrRd']

  # view study overviews and downloads
  def index
    @study_count = Study.count
    @cell_count = Study.all.map(&:cell_count).inject(&:+)
    # set study order
    case params[:order]
      when 'recent'
        @order = :created_at.desc
      when 'popular'
        @order = :view_count.desc
      else
        @order = [:view_order.asc, :name.asc]
    end

    # load viewable studies in requested order
    if user_signed_in?
      @viewable = Study.viewable(current_user).order_by(@order)
    else
      @viewable = Study.where(public: true).order_by(@order)
    end

    # if search params are present, filter accordingly
    if !params[:search_terms].blank?
      @studies = @viewable.where({:$text => {:$search => params[:search_terms]}}).paginate(page: params[:page], per_page: Study.per_page)
    else
      @studies = @viewable.paginate(page: params[:page], per_page: Study.per_page)
    end
  end

  # search for matching studies
  def search
    # use built-in MongoDB text index (supports quoting terms & case sensitivity)
    @studies = Study.where({:$text => {:$search => params[:search_terms]}})
    render 'index'
  end

  # load single study and view top-level clusters
  def study
    @study.update(view_count: @study.view_count + 1)
    @study_files = @study.study_files.delete_if {|sf| sf.file_type == 'fastq'}.sort_by(&:name)
    # parse all coordinates out into hash using generic method
    if @study.initialized?
      @options = load_cluster_group_options
      @cluster_annotations = load_cluster_group_annotations
      # call set_selected_annotation manually
      set_selected_annotation
    end
  end

  # render a single cluster and its constituent sub-clusters
  def render_cluster
    @coordinates = load_cluster_group_data_array_points(@selected_annotation)
    @plot_type = @cluster.cluster_type == '3d' ? 'scatter3d' : 'scattergl'
    @options = load_cluster_group_options
    @cluster_annotations = load_cluster_group_annotations
    @range = set_range(@coordinates.values)
    @axes = load_axis_labels
  end

  # dynamically reload cluster-based annotations list when changing clusters
  def get_new_annotations
    @cluster_annotations = load_cluster_group_annotations
  end

  # method to download files if study is private, will create temporary symlink and remove after timeout
  def download_file
    @study_file = @study.study_files.select {|sf| sf.upload_file_name == params[:filename]}.first
    begin
      @signed_url = Study.firecloud_client.execute_gcloud_method(:generate_signed_url, @study.firecloud_workspace, @study_file.upload_file_name, expires: 15)
    rescue RuntimeError => e
      logger.error "#{Time.now}: error generating signed url for #{@study_file.upload_file_name}; #{e.message}"
      redirect_to request.referrer, alert: "We were unable to download the file #{@study_file.upload_file_name} do to an error: #{e.message}" and return
    end
    # redirect directly to file to trigger download
    redirect_to @signed_url
  end

  # method to download fastq file directly from bucket
  def download_fastq_file
    begin
      @signed_url = Study.firecloud_client.execute_gcloud_method(:generate_signed_url, @study.firecloud_workspace, params[:filename], expires: 15)
    rescue RuntimeError => e
      logger.error "#{Time.now}: error generating signed url for #{params[:filename]}; #{e.message}"
      redirect_to request.referrer, alert: "We were unable to download the file #{params[:filename]} do to an error: #{e.message}" and return
    end
    # redirect directly to file to trigger download
    redirect_to @signed_url
  end

  # search for one or more genes to view expression information
  def search_genes
    if params[:search][:upload].blank?
      terms = parse_search_terms(:genes)
      @genes = load_expression_scores(terms)
    else
      geneset_file = params[:search][:upload]
      terms = geneset_file.read.split(/[\s\r\n?,]/).map {|gene| gene.strip}
      @genes = load_expression_scores(terms)
    end
    # grab saved params for loaded cluster and boxpoints mode
    cluster = params[:search][:cluster]
    annotation = params[:search][:annotation]
    boxpoints = params[:search][:boxpoints]

    # check if one gene was searched for, but more than one found
    # we can assume that in this case there is an exact match possible
    # cast as an array so block after still works properly
    if @genes.size > 1 && terms.size == 1
      @genes = [load_best_gene_match(@genes, terms.first)]
    end

    # determine which view to load
    if @genes.empty?
      redirect_to request.referrer, alert: "No matches found for: #{terms.join(', ')}."
    elsif @genes.size > 1
      redirect_to view_gene_expression_heatmap_path(search: {genes: terms.join(' ')}, cluster: cluster, annotation: annotation)
    else
      gene = @genes.first
      redirect_to view_gene_expression_path(study_name: params[:study_name], gene: gene.gene, cluster: cluster, boxpoints: boxpoints, annotation: annotation)
    end
  end

  # render box and scatter plots for parent clusters or a particular sub cluster
  def view_gene_expression
    # we don't need to call by_gene since we know we have an exact match (or were redirected to the closest possible by search_genes)
    @gene = @study.expression_scores.find_by(gene: params[:gene])
    @options = load_cluster_group_options
    @cluster_annotations = load_cluster_group_annotations
    @top_plot_partial = @selected_annotation[:type] == 'group' ? 'expression_plots_view' : 'expression_annotation_plots_view'
  end

  # re-renders plots when changing cluster selection
  def render_gene_expression_plots
    matches = @study.expression_scores.by_gene(params[:gene])
    @gene = load_best_gene_match(matches, params[:gene])
    @y_axis_title = @study.expression_matrix_file.y_axis_label
    # depending on annotation type selection, set up necessary partial names to use in rendering
    if @selected_annotation[:type] == 'group'
      @values = load_expression_boxplot_data_array_scores(@selected_annotation)
      @top_plot_partial = 'expression_plots_view'
      @top_plot_plotly = 'expression_plots_plotly'
      @top_plot_layout = 'expression_box_layout'
    else
      @values = load_annotation_based_data_array_scatter(@selected_annotation)
      @top_plot_partial = 'expression_annotation_plots_view'
      @top_plot_plotly = 'expression_annotation_plots_plotly'
      @top_plot_layout = 'expression_annotation_scatter_layout'
      @annotation_scatter_range = set_range(@values.values)
    end
    @expression = load_expression_data_array_points(@selected_annotation)
    @options = load_cluster_group_options
    @range = set_range([@expression[:all]])
    @coordinates = load_cluster_group_data_array_points(@selected_annotation)
    @static_range = set_range(@coordinates.values)
    @cluster_annotations = load_cluster_group_annotations
  end

  # view set of genes (scores averaged) as box and scatter plots
  def view_gene_set_expression
    precomputed = @study.precomputed_scores.by_name(params[:gene_set])
    @genes = []
    precomputed.gene_list.each do |gene|
      matches = @study.expression_scores.by_gene(gene)
      matches.map {|gene| @genes << gene}
    end
    @y_axis_title = 'Mean ' + @study.expression_matrix_file.y_axis_label
    # depending on annotation type selection, set up necessary partial names to use in rendering
		@options = load_cluster_group_options
		@cluster_annotations = load_cluster_group_annotations
		@top_plot_partial = @selected_annotation[:type] == 'group' ? 'expression_plots_view' : 'expression_annotation_plots_view'

    if @genes.size > 5
      @main_genes, @other_genes = divide_genes_for_header
    end
    render 'view_gene_expression'
  end

  # re-renders plots when changing cluster selection
  def render_gene_set_expression_plots
    precomputed = @study.precomputed_scores.by_name(params[:gene_set])
    @genes = []
    precomputed.gene_list.each do |gene|
      matches = @study.expression_scores.by_gene(gene)
      matches.map {|gene| @genes << gene}
    end
    @y_axis_title = 'Mean ' + @study.expression_matrix_file.y_axis_label
    # depending on annotation type selection, set up necessary partial names to use in rendering
    if @selected_annotation[:type] == 'group'
      @values = load_gene_set_expression_boxplot_scores(@selected_annotation)
      @top_plot_partial = 'expression_plots_view'
      @top_plot_plotly = 'expression_plots_plotly'
      @top_plot_layout = 'expression_box_layout'
    else
      @values = load_gene_set_annotation_based_scatter(@selected_annotation)
      @top_plot_partial = 'expression_annotation_plots_view'
      @top_plot_plotly = 'expression_annotation_plots_plotly'
      @top_plot_layout = 'expression_annotation_scatter_layout'
      @annotation_scatter_range = set_range(@values.values)
    end
    # load expression scatter using main gene expression values
    @expression = load_gene_set_expression_data_arrays(@selected_annotation)
    color_minmax =  @expression[:all][:marker][:color].minmax
    @expression[:all][:marker][:cmin], @expression[:all][:marker][:cmax] = color_minmax
    @expression[:all][:marker][:colorscale] = 'Reds'
    # load static cluster reference plot
    @coordinates = load_cluster_group_data_array_points(@selected_annotation)
    # set up options, annotations and ranges
    @options = load_cluster_group_options
    @range = set_range([@expression[:all]])
    @static_range = set_range(@coordinates.values)
    @cluster_annotations = load_cluster_group_annotations

    if @genes.size > 5
      @main_genes, @other_genes = divide_genes_for_header
    end
    render 'render_gene_expression_plots'
  end

  # view genes in Morpheus as heatmap
  def view_gene_expression_heatmap
    # parse and divide up genes
    terms = parse_search_terms(:genes)
    @genes, @not_found = search_expression_scores(terms)

    # load dropdown options
    @options = load_cluster_group_options
    @cluster_annotations = load_cluster_group_annotations
    if @genes.size > 5
      @main_genes, @other_genes = divide_genes_for_header
    end

  end

  # load data in gct form to render in Morpheus, preserving query order
  def expression_query
    terms = parse_search_terms(:genes)
    @genes = load_expression_scores(terms)
    @headers = ["Name", "Description"]
    @cells = @cluster.concatenate_data_arrays('text', 'cells')
    @cols = @cells.size
    @cells.each do |cell|
      @headers << cell
    end

    @rows = []
    @genes.each do |gene|
      row = [gene.gene, ""]
      # calculate mean to perform row centering if requested
      mean = 0.0
      if params[:row_centered] == '1'
        mean = gene.mean(@cells)
      end
      @cells.each do |cell|
        row << gene.scores[cell].to_f - mean
      end

      @rows << row.join("\t")
    end
    @data = ['#1.2', [@rows.size, @cols].join("\t"), @headers.join("\t"), @rows.join("\n")].join("\n")

    send_data @data, type: 'text/plain'
  end

  # load annotations in tsv format for Morpheus
  def annotation_query
    @cells = @cluster.concatenate_data_arrays('text', 'cells')
    if @selected_annotation[:scope] == 'cluster'
      @annotations = @cluster.concatenate_data_arrays(@selected_annotation[:name], 'annotations')
    else
      study_annotations = @study.study_metadata_values(@selected_annotation[:name], @selected_annotation[:type])
      @annotations = []
      @cells.each do |cell|
        @annotations << study_annotations[cell]
      end
    end
    # assemble rows of data
    @rows = []
    @cells.each_with_index do |cell, index|
      @rows << [cell, @annotations[index]].join("\t")
    end
    @headers = ['NAME', @selected_annotation[:name]]
    @data = [@headers.join("\t"), @rows.join("\n")].join("\n")
    send_data @data, type: 'text/plain'
  end

  # load precomputed data in gct form to render in Morpheus
  def precomputed_results
    @precomputed_score = @study.precomputed_scores.by_name(params[:precomputed])

    @headers = ["Name", "Description"]
    @precomputed_score.clusters.each do |cluster|
      @headers << cluster
    end
    @rows = []
    @precomputed_score.gene_scores.each do |score_row|
      score_row.each do |gene, scores|
        row = [gene, ""]
        mean = 0.0
        if params[:row_centered] == '1'
          mean = scores.values.inject(0) {|sum, x| sum += x} / scores.values.size
        end
        @precomputed_score.clusters.each do |cluster|
          row << scores[cluster].to_f - mean
        end
        @rows << row.join("\t")
      end
    end
    @data = ['#1.2', [@rows.size, @precomputed_score.clusters.size].join("\t"), @headers.join("\t"), @rows.join("\n")].join("\n")

    send_data @data, type: 'text/plain', filename: 'query.gct'
  end

  # view all genes as heatmap in morpheus, will pull from pre-computed gct file
  def view_all_gene_expression_heatmap
  end

  # redirect to show precomputed marker gene results
  def search_precomputed_results
    redirect_to view_precomputed_gene_expression_heatmap_path(study_name: params[:study_name], precomputed: params[:expression])
  end

  # view all genes as heatmap in morpheus, will pull from pre-computed gct file
  def view_precomputed_gene_expression_heatmap
    @precomputed_score = @study.precomputed_scores.by_name(params[:precomputed])
    @options = load_cluster_group_options
    @cluster_annotations = load_cluster_group_annotations
  end

  # method to populate an array with entries corresponding to all fastq files for a study (both owner defined as study_files
  # and extra fastq's that happen to be in the bucket)
  def get_fastq_files
    # load study_file fastqs first
    @fastq_files = {data: []}
    study_fastqs = @study.study_files.select {|sf| sf.file_type == 'fastq'}
    study_fastqs.each do |sfq|
      @download = ""
      if sfq.human_data == true
        @download = view_context.link_to("<span class='fa fa-cloud-download'></span> External".html_safe, sfq.download_path, class: 'btn btn-primary', target: :_blank)
      else
        @download = view_context.link_to("<span class='fa fa-download'></span> #{number_to_human_size(sfq.upload_file_size, prefix: :si)}".html_safe, sfq.download_path, class: "btn btn-primary dl-link #{sfq.file_type_class}", download: sfq.upload_file_name)
      end

      @fastq_files << [
          sfq.name,
          sfq.description,
          @download
      ]
    end

    # call workspace bucket to find all fastq files
    begin
      @bucket_fastqs = []
      bucket_files = Study.firecloud_client.execute_gcloud_method(:get_workspace_files, @study.firecloud_workspace)

      # add initial list to array if a fastq
      bucket_files.map do |bf|
        if bf.name =~ /\.(fq|fastq)/
          @bucket_fastqs << bf
        end
      end

      # since we might have a lot of files, wrap in block calling next?
      while bucket_files.next?
        files = bucket_files.next
        files.map do |f|
          if f.name =~ /\.(fq|fastq)/
            @bucket_fastqs << f
          end
        end
      end
    rescue RuntimeError => e
      logger.error "#{Time.now}: error loading fastq files from #{@study.firecloud_workspace}; #{e.message}"
      @fastq_files[:data] << ['Error loading fastq files from workspace', '', '']
    end

    @bucket_fastqs.each do |bucket_fastq|
      bucket_entry = [
          bucket_fastq.name,
          '',
          view_context.link_to("<span class='fa fa-download'></span> #{view_context.number_to_human_size(bucket_fastq.size, prefix: :si)}".html_safe, @study.public? ? download_fastq_file_path(@study.url_safe_name, URI.encode(bucket_fastq.name)) : download_private_fastq_file_path(@study.url_safe_name, URI.encode(bucket_fastq.name)), class: "btn btn-primary dl-link fastq-file", download: bucket_fastq.name)
      ]
      if @fastq_files[:data].select {|f| f.first == bucket_fastq.name}.nil?
        @fastq_files[:data] << bucket_entry
      end
    end
    render json: @fastq_files.to_json
  end

  private

  # SETTERS
  def set_study
    @study = Study.where(url_safe_name: params[:study_name]).first
  end

  def set_cluster_group
    # determine which URL param to use for selection
    selector = params[:cluster].nil? ? params[:gene_set_cluster] : params[:cluster]
    if selector.nil?
      @cluster = @study.cluster_groups.first
    else
      @cluster = @study.cluster_groups.select {|c| c.name == selector}.first
    end
  end

  def set_selected_annotation
    # determine which URL param to use for selection
    selector = params[:annotation].nil? ? params[:gene_set_annotation] : params[:annotation]
    if selector.nil?
      @selected_annotation = @cluster.cell_annotations.first
    else
      # determine whether cluster- or study-level annotations are requested
      annot_name, annot_type, annot_scope = selector.split('--')
      if annot_scope == 'cluster'
        @selected_annotation = @cluster.cell_annotations.select {|ca| ca[:name] == annot_name && ca[:type] == annot_type}.first
      else
        @selected_annotation = {name: annot_name, type: annot_type, scope: annot_scope}
        if annot_type == 'group'
          @selected_annotation[:values] = @study.study_metadata_keys(annot_name, annot_type)
        end
      end
      @selected_annotation[:scope] = annot_scope
      @selected_annotation
    end
  end

  def check_view_permissions
    unless @study.public?
      if (!user_signed_in? && !@study.public?) || (user_signed_in? && !@study.can_view?(current_user))
        redirect_to site_path, alert: 'You do not have permission to view the requested page' and return
      end
    end
  end

	# SUB METHODS

  # generic method to populate data structure to render a cluster scatter plot
  # uses cluster_group model and loads annotation for both group & numeric plots
  # data values are pulled from associated data_array entries for each axis and annotation/text value
  def load_cluster_group_data_array_points(annotation)
    x_array = @cluster.concatenate_data_arrays('x', 'coordinates')
    y_array = @cluster.concatenate_data_arrays('y', 'coordinates')
    z_array = @cluster.concatenate_data_arrays('z', 'coordinates')
    cells = @cluster.concatenate_data_arrays('text', 'cells')
    annotation_array = []
    annotation_hash = {}
    if annotation[:scope] == 'cluster'
      annotation_array = @cluster.concatenate_data_arrays(annotation[:name], 'annotations')
    else
      # for study-wide annotations, load from study_metadata values instead of cluster-specific annotations
      annotation_hash = @study.study_metadata_values(annotation[:name], annotation[:type])
      annotation[:values] = @study.study_metadata_keys(annotation[:name], annotation[:type])
    end
    coordinates = {}
    if annotation[:type] == 'numeric'
      text_array = []
      color_array = []
      # load text & color value from correct object depending on annotation scope
      cells.each_with_index do |cell, index|
        if annotation[:scope] == 'cluster'
          val = annotation_array[index]
          text_array << "#{cell}: (#{val})"
        else
          val = annotation_hash[cell]
          text_array <<  "#{cell}: (#{val})"
          color_array << val
        end
      end
      # if we didn't assign anything to the color array, we know the annotation_array is good to use
      color_array.empty? ? color_array = annotation_array : nil
      coordinates[:all] = {
          x: x_array,
          y: y_array,
          z: z_array,
          text: text_array,
          name: annotation[:name],
          marker: {
              cmax: annotation_array.max,
              cmin: annotation_array.min,
              color: color_array,
              size: color_array.map {|a| 6},
              line: { color: 'rgb(40,40,40)', width: 0.5},
              colorscale: 'Reds',
              showscale: true,
              colorbar: {
                  title: annotation[:name] ,
                  titleside: 'right'
              }
          }
      }
    else
      # assemble containers for each trace
      annotation[:values].each do |value|
        coordinates[value] = {x: [], y: [], z: [], text: [], name: "#{annotation[:name]}: #{value}", marker_size: []}
      end
      if annotation[:scope] == 'cluster'
        annotation_array.each_with_index do |annotation_value, index|
          coordinates[annotation_value][:text] << "<b>#{cells[index]}</b><br>#{annotation[:name]}: #{annotation_value}"
          coordinates[annotation_value][:x] << x_array[index]
          coordinates[annotation_value][:y] << y_array[index]
          if @cluster.cluster_type == '3d'
            coordinates[annotation_value][:z] << z_array[index]
          end
          coordinates[annotation_value][:marker_size] << 6
        end
        coordinates.each do |key, data|
          data[:name] << " (#{data[:x].size} points)"
        end
      else
        cells.each_with_index do |cell, index|
          if annotation_hash.has_key?(cell)
            annotation_value = annotation_hash[cell]
            coordinates[annotation_value][:text] << "<b>#{cell}</b><br>#{annotation[:name]}: #{annotation_value}"
            coordinates[annotation_value][:x] << x_array[index]
            coordinates[annotation_value][:y] << y_array[index]
            if @cluster.cluster_type == '3d'
              coordinates[annotation_value][:z] << z_array[index]
            end
            coordinates[annotation_value][:marker_size] << 6
          end
        end
        coordinates.each do |key, data|
          data[:name] << " (#{data[:x].size} points)"
        end
        # gotcha to remove entries in case a particular annotation value comes up blank since this is study-wide
        coordinates.delete_if {|key, data| data[:x].empty?}
      end
    end
    coordinates
  end

  # method to load a 2-d scatter of selected numeric annotation vs. gene expression
  def load_annotation_based_data_array_scatter(annotation)
    cells = @cluster.concatenate_data_arrays('text', 'cells')
    annotation_array = []
    annotation_hash = {}
    if annotation[:scope] == 'cluster'
      annotation_array = @cluster.concatenate_data_arrays(annotation[:name], 'annotations')
    else
      annotation_hash = @study.study_metadata_values(annotation[:name], annotation[:type])
    end
    values = {}
    values[:all] = {x: [], y: [], text: [], marker_size: []}
    if annotation[:scope] == 'cluster'
      annotation_array.each_with_index do |annot, index|
        annotation_value = annot
        cell_name = cells[index]
        expression_value = @gene.scores[cell_name].to_f.round(4)
        values[:all][:text] << "<b>#{cell_name}</b><br>#{annotation[:name]}: #{annotation_value}<br>#{@y_axis_title}: #{expression_value}"
        values[:all][:x] << annotation_value
        values[:all][:y] << expression_value
        values[:all][:marker_size] << 6
      end
    else
      cells.each_with_index do |cell, index|
        if annotation_hash.has_key?(cell)
          annotation_value = annotation_hash[cell]
          expression_value = @gene.scores[cell].to_f.round(4)
          values[:all][:text] << "<b>#{cell}</b><br>#{annotation[:name]}: #{annotation_value}<br>#{@y_axis_title}: #{expression_value}"
          values[:all][:x] << annotation_value
          values[:all][:y] << expression_value
          values[:all][:marker_size] << 6
        end
      end
    end
    values
  end

  # method to load a 2-d scatter of selected numeric annotation vs. gene set expression (mean)
  def load_gene_set_annotation_based_scatter(annotation)
    values = {}
    values[:all] = {x: [], y: [], text: [], marker_size: []}
		cells = @cluster.concatenate_data_arrays('text', 'cells')
    annotation_array = []
    annotation_hash = {}
    if annotation[:scope] == 'cluster'
      annotation_array = @cluster.concatenate_data_arrays(annotation[:name], 'annotations')
    else
      annotation_hash = @study.study_metadata_values(annotation[:name], annotation[:type])
    end
    cells.each_with_index do |cell|
      annotation_value = annotation[:scope] == 'cluster' ? annotation_array[index] : annotation_hash[cell]
      expression_value = calculate_mean(@genes, cell)
      values[:all][:text] << "<b>#{cell}</b><br>#{annotation[:name]}: #{annotation_value}<br>#{@y_axis_title}: #{expression_value}"
      values[:all][:x] << annotation_value
      values[:all][:y] << expression_value
      values[:all][:marker_size] << 6
    end
    values
  end

  # load box plot scores from gene expression values using data array of cell names for given cluster
  def load_expression_boxplot_data_array_scores(annotation)
    values = initialize_plotly_objects_by_annotation(annotation)

    # grab all cells present in the cluster, and use as keys to load expression scores
    # if a cell is not present for the gene, score gets set as 0.0
    # will check if there are more than SUBSAMPLE_THRESHOLD cells present in the cluster, and subsample accordingly
    # values hash will be assembled differently depending on annotation scope (cluster-based is array, study-based is a hash)
    all_cells = @cluster.concatenate_data_arrays('text', 'cells')
    cells = all_cells.count > ClusterGroup::SUBSAMPLE_THRESHOLD ? all_cells.shuffle(random: Random.new(1)).take(ClusterGroup::SUBSAMPLE_THRESHOLD) : all_cells
    if annotation[:scope] == 'cluster'
      all_annotations = @cluster.concatenate_data_arrays(annotation[:name], 'annotations')
      annotations = all_annotations.count > ClusterGroup::SUBSAMPLE_THRESHOLD ? all_annotations.shuffle(random: Random.new(1)).take(ClusterGroup::SUBSAMPLE_THRESHOLD) : all_annotations
      cells.each_with_index do |cell, index|
        values[annotations[index]][:y] << @gene.scores[cell].to_f.round(4)
      end
    else
      all_annotations = @study.study_metadata_values(annotation[:name], annotation[:type])
      # since annotations are in hash format, we must cast as an array to subsample then cast back to a hash
      annotations = all_annotations.count > StudyMetadata::SUBSAMPLE_THRESHOLD ? Hash[all_annotations.to_a.shuffle(random: Random.new(1)).take(StudyMetadata::SUBSAMPLE_THRESHOLD)] : all_annotations
      cells.each do |cell|
        val = annotations[cell]
        # must check if key exists
        if values.has_key?(val)
          values[annotations[cell]][:y] << @gene.scores[cell].to_f.round(4)
        end
      end
      # remove any empty values as annotations may have created keys that don't exist in cluster
      values.delete_if {|key, data| data[:y].empty?}
    end
    values
  end

  # load cluster_group data_array values, but use expression scores to set numerical color array
  def load_expression_data_array_points(annotation)
    x_array = @cluster.concatenate_data_arrays('x', 'coordinates')
    y_array = @cluster.concatenate_data_arrays('y', 'coordinates')
    z_array = @cluster.concatenate_data_arrays('z', 'coordinates')
    cells = @cluster.concatenate_data_arrays('text', 'cells')
    annotation_array = []
    annotation_hash = {}
    if annotation[:scope] == 'cluster'
      annotation_array = @cluster.concatenate_data_arrays(annotation[:name], 'annotations')
    else
      # for study-wide annotations, load from study_metadata values instead of cluster-specific annotations
      annotation_hash = @study.study_metadata_values(annotation[:name], annotation[:type])
    end
    expression = {}
    expression[:all] = {
        x: x_array,
        y: y_array,
        z: z_array,
        text: [],
        marker: {cmax: 0, cmin: 0, color: [], size: [], showscale: true, colorbar: {title: @y_axis_title , titleside: 'right'}}
    }
    cells.each_with_index do |cell, index|
      expression_score = @gene.scores[cell].to_f.round(4)
      # load correct annotation value based on scope
      annotation_value = annotation[:scope] == 'cluster' ? annotation_array[index] : annotation_hash[cell]
      text_value = "#{cell} (#{annotation[:name]}: #{annotation_value})<br />#{@y_axis_title}: #{expression_score}"
      expression[:all][:text] << text_value
      expression[:all][:marker][:color] << expression_score
      expression[:all][:marker][:size] << 6
    end
    color_minmax =  expression[:all][:marker][:color].minmax
    expression[:all][:marker][:cmin], expression[:all][:marker][:cmax] = color_minmax
    expression[:all][:marker][:colorscale] = 'Reds'
    expression
  end

  # load boxplot expression scores with average of scores across each gene for all cells
  def load_gene_set_expression_boxplot_scores(annotation)
		values = initialize_plotly_objects_by_annotation(annotation)

    # grab all cells present in the cluster, and use as keys to load expression scores
    # if a cell is not present for the gene, score gets set as 0.0
    # will check if there are more than SUBSAMPLE_THRESHOLD cells present in the cluster, and subsample accordingly
    # values hash will be assembled differently depending on annotation scope (cluster-based is array, study-based is a hash)
    all_cells = @cluster.concatenate_data_arrays('text', 'cells')
    cells = all_cells.count > ClusterGroup::SUBSAMPLE_THRESHOLD ? all_cells.shuffle(random: Random.new(1)).take(ClusterGroup::SUBSAMPLE_THRESHOLD) : all_cells
    if annotation[:scope] == 'cluster'
      all_annotations = @cluster.concatenate_data_arrays(annotation[:name], 'annotations')
      annotations = all_annotations.count > ClusterGroup::SUBSAMPLE_THRESHOLD ? all_annotations.shuffle(random: Random.new(1)).take(ClusterGroup::SUBSAMPLE_THRESHOLD) : all_annotations
      cells.each_with_index do |cell, index|
        values[annotations[index]][:y] << calculate_mean(@genes, cell)
      end
    else
      all_annotations = @study.study_metadata_values(annotation[:name], annotation[:type])
      # since annotations are in hash format, we must cast as an array to subsample then cast back to a hash
      annotations = all_annotations.count > StudyMetadata::SUBSAMPLE_THRESHOLD ? Hash[all_annotations.to_a.shuffle(random: Random.new(1)).take(StudyMetadata::SUBSAMPLE_THRESHOLD)] : all_annotations
      cells.each do |cell|
        val = annotations[cell]
        # must check if key exists
        if values.has_key?(val)
          values[annotations[cell]][:y] << calculate_mean(@genes, cell)
        end
      end
      # remove any empty values as annotations may have created keys that don't exist in cluster
      values.delete_if {|key, data| data[:y].empty?}
    end
    values
  end

  # load scatter expression scores with average of scores across each gene for all cells
	# uses data_array as source for each axis
	def load_gene_set_expression_data_arrays(annotation)
		x_array = @cluster.concatenate_data_arrays('x', 'coordinates')
		y_array = @cluster.concatenate_data_arrays('y', 'coordinates')
		z_array = @cluster.concatenate_data_arrays('z', 'coordinates')
		cells = @cluster.concatenate_data_arrays('text', 'cells')
    annotation_array = []
    annotation_hash = {}
    if annotation[:scope] == 'cluster'
      annotation_array = @cluster.concatenate_data_arrays(annotation[:name], 'annotations')
    else
      # for study-wide annotations, load from study_metadata values instead of cluster-specific annotations
      annotation_hash = @study.study_metadata_values(annotation[:name], annotation[:type])
    end
		expression = {}
		expression[:all] = {
				x: x_array,
				y: y_array,
				z: z_array,
				text: [],
				marker: {cmax: 0, cmin: 0, color: [], size: [], showscale: true, colorbar: {title: @y_axis_title , titleside: 'right'}}
		}
		cells.each_with_index do |cell, index|
			expression_score = calculate_mean(@genes, cell)
      # load correct annotation value based on scope
      annotation_value = annotation[:scope] == 'cluster' ? annotation_array[index] : annotation_hash[cell]
      text_value = "#{cell} (#{annotation[:name]}: #{annotation_value})<br />#{@y_axis_title}: #{expression_score}"
			expression[:all][:text] << text_value
			expression[:all][:marker][:color] << expression_score
			expression[:all][:marker][:line] = { color: 'rgb(40,40,40)', width: 0.5}
			expression[:all][:marker][:size] << 6
		end
		color_minmax =  expression[:all][:marker][:color].minmax
		expression[:all][:marker][:cmin], expression[:all][:marker][:cmax] = color_minmax
		expression[:all][:marker][:colorscale] = 'Reds'
		expression
	end

  # method to initialize containers for plotly by annotation values
  def initialize_plotly_objects_by_annotation(annotation)
    values = {}
    annotation[:values].each do |value|
      values["#{value}"] = {y: [], name: "#{annotation[:name]}: #{value}" }
    end
    values
  end

  # find mean of expression scores for a given cell
  def calculate_mean(genes, cell)
    sum = 0.0
    genes.each do |gene|
      sum += gene.scores[cell].to_f
    end
    sum / genes.size
  end

  # generic search term parser
  def parse_search_terms(key)
    terms = params[:search][key]
    if terms.is_a?(Array)
      terms.first.split(/[\s\n,]/).map {|gene| gene.strip}
    else
      terms.split(/[\s\n,]/).map {|gene| gene.strip}
    end
  end

  # generic expression score getter, preserves order and discards empty matches
  def load_expression_scores(terms)
    genes = []
    terms.each do |term|
      matches = @study.expression_scores.by_gene(term)
      unless matches.empty?
        matches.map {|gene| genes << gene}
      end
    end
    genes
  end

  # search genes and save terms not found
  def search_expression_scores(terms)
    genes = []
    not_found = []
    terms.each do |term|
      matches = @study.expression_scores.by_gene(term)
      unless matches.empty?
        matches.map {|gene| genes << gene}
      else
        not_found << term
      end
    end
    [genes, not_found]
  end

  # load best-matching gene (if possible)
  def load_best_gene_match(matches, search_term)
    # iterate through all matches to see if there is an exact match
    matches.each do |match|
      if match.gene == search_term
        return match
      end
    end
    # did not find an exact match, so just return the first one
    matches.first
  end

  # helper method to load all possible cluster groups for a study
  def load_cluster_group_options
    @study.cluster_groups.map(&:name)
  end

  # helper method to load all available cluster_group-specific annotations
  def load_cluster_group_annotations
    grouped_options = {
        'Cluster-based' => @cluster.cell_annotations.map {|annot| ["#{annot[:name]}", "#{annot[:name]}--#{annot[:type]}--cluster"]},
        'Study Wide' => @study.study_metadatas.map {|metadata| ["#{metadata.name}", "#{metadata.name}--#{metadata.annotation_type}--study"] }.uniq
    }
    grouped_options
  end

  # defaults for annotation fonts
  def annotation_font
    {
        family: 'Helvetica Neue',
        size: 10,
        color: '#333'
    }
  end

  # set the range for a plotly scatter, will default to data-defined if cluster hasn't defined its own ranges
  def set_range(inputs)
    range = {
        x: [],
        y: [],
        z: []
    }
    if @cluster.has_range?
      range = @cluster.domain_ranges
    else
      vals = inputs.map {|v| [v[:x].minmax, v[:y].minmax, v[:z].minmax]}.flatten.compact.minmax
      # add 2% padding to range
      scope = (vals.first - vals.last) * 0.02
      raw_range = [vals.first + scope, vals.last - scope]
      range[:x] = raw_range
      range[:y] = raw_range
      range[:z] = raw_range
    end
    range
  end

  # parse gene list into 2 other arrays for formatting the header responsively
  def divide_genes_for_header
    main = @genes[0..4]
    more = @genes[5..@genes.size - 1]
    [main, more]
  end

  # load all precomputed options for a study
  def load_precomputed_options
     @precomputed = @study.precomputed_scores.map(&:name)
  end

  # retrieve axis labels from cluster coordinates file (if provided)
  def load_axis_labels
    coordinates_file = @cluster.study_file
    {
        x: coordinates_file.x_axis_label.blank? ? 'X' : coordinates_file.x_axis_label,
        y: coordinates_file.y_axis_label.blank? ? 'Y' : coordinates_file.y_axis_label,
        z: coordinates_file.z_axis_label.blank? ? 'Z' : coordinates_file.z_axis_label
    }
  end
end
