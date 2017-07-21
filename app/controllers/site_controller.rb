class SiteController < ApplicationController

  respond_to :html, :js, :json

  before_action :set_study, except: [:index, :search]
  before_action :load_precomputed_options, except: [:index, :search, :edit_study_description, :annotation_query, :download_file, :get_fastq_files]
  before_action :set_cluster_group, except: [:index, :search, :update_study_settings, :edit_study_description, :precomputed_results, :download_file, :get_fastq_files]
  before_action :set_selected_annotation, except: [:index, :search, :study, :update_study_settings, :edit_study_description, :precomputed_results, :expression_query, :get_new_annotations, :download_file, :get_fastq_files]
  before_action :check_view_permissions, except: [:index, :search, :precomputed_results, :expression_query]

  # caching
  caches_action :render_cluster, :render_gene_expression_plots, :render_gene_set_expression_plots,
                :expression_query, :annotation_query, :precomputed_results,
                cache_path: :set_cache_path

  COLORSCALE_THEMES = %w(Blackbody Bluered Blues Earth Electric Greens Hot Jet Picnic Portland Rainbow RdBu Reds Viridis YlGnBu YlOrRd)

  # view study overviews and downloads
  def index
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

    # determine study/cell count based on viewable to user
    @study_count = @viewable.count
    @cell_count = @viewable.map(&:cell_count).inject(&:+)
  end

  # search for matching studies
  def search
    # use built-in MongoDB text index (supports quoting terms & case sensitivity)
    @studies = Study.where({'$text' => {'$search' => params[:search_terms]}})
    render 'index'
  end

  # load single study and view top-level clusters
  def study
    @study.update(view_count: @study.view_count + 1)
    @study_files = @study.study_files.non_primary_data.sort_by(&:name)
    @directories = @study.directory_listings.are_synced

    # double check on download availability: first, check if administrator has disabled downloads
    # then check if FireCloud is available and disable download links if either is true
    @allow_downloads = AdminConfiguration.firecloud_access_enabled? && Study.firecloud_client.api_available?
    set_study_default_options
    # load options and annotations
    if @study.initialized?
      @options = load_cluster_group_options
      @cluster_annotations = load_cluster_group_annotations
      # call set_selected_annotation manually
      set_selected_annotation
    end
  end

  # re-render study description as CKEditor instance
  def edit_study_description

  end

  # update selected attributes via study settings tab
  def update_study_settings
    if @study.update(study_params)
      # invalidate caches as needed
      if @study.previous_changes.keys.include?('default_options')
        @study.default_cluster.study_file.invalidate_cache_by_file_type
      elsif @study.previous_changes.keys.include?('name')
        # if user renames a study, invalidate all caches
        old_name = @study.previous_changes['url_safe_name'].first
        CacheRemovalJob.new(old_name).delay.perform
      end
      set_study_default_options
      if @study.initialized?
        @cluster = @study.default_cluster
        @options = load_cluster_group_options
        @cluster_annotations = load_cluster_group_annotations
        set_selected_annotation
      end
      @study_files = @study.study_files.non_primary_data.sort_by(&:name)
      @directories = @study.directory_listings.are_synced

      # double check on download availability: first, check if administrator has disabled downloads
      # then check if FireCloud is available and disable download links if either is true
      @allow_downloads = AdminConfiguration.firecloud_access_enabled? && Study.firecloud_client.api_available?
    else
      set_study_default_options
    end
  end

  # render a single cluster and its constituent sub-clusters
  def render_cluster
    subsample = params[:subsample].blank? ? nil : params[:subsample].to_i
    @coordinates = load_cluster_group_data_array_points(@selected_annotation, subsample)

    @plot_type = @cluster.cluster_type == '3d' ? 'scatter3d' : 'scattergl'
    @options = load_cluster_group_options
    @cluster_annotations = load_cluster_group_annotations
    @range = set_range(@coordinates.values)
    if @cluster.is_3d? && @cluster.has_range?
      @aspect = compute_aspect_ratios(@range)
    end
    @axes = load_axis_labels

    # load default color profile if necessary
    if params[:annotation] == @study.default_annotation && @study.default_annotation_type == 'numeric' && !@study.default_color_profile.nil?
      @coordinates[:all][:marker][:colorscale] = @study.default_color_profile
    end

    respond_to do |format|
      format.js
    end
  end

  # dynamically reload cluster-based annotations list when changing clusters
  def get_new_annotations
    @cluster_annotations = load_cluster_group_annotations
  end

  # method to download files if study is public
  def download_file
    if !user_signed_in?
      redirect_to view_study_path(@study.url_safe_name), alert: 'You must be signed in to download data.' and return
    end

    # next check if downloads have been disabled by administrator, this will abort the download
    # download links shouldn't be rendered in any case, this just catches someone doing a straight GET on a file
    # also check if FireCloud is unavailable and abort if so as well
    if !AdminConfiguration.firecloud_access_enabled? || !Study.firecloud_client.api_available?
      head 503 and return
    end

    # get filesize and make sure the user is under their quota
    begin
      filesize = Study.firecloud_client.execute_gcloud_method(:get_workspace_file, @study.firecloud_workspace, params[:filename]).size
      user_quota = current_user.daily_download_quota + filesize
      # check against download quota that is loaded in ApplicationController.get_download_quota
      if user_quota <= @download_quota
        @signed_url = Study.firecloud_client.execute_gcloud_method(:generate_signed_url, @study.firecloud_workspace, params[:filename], expires: 15)
        current_user.update(daily_download_quota: user_quota)
      else
        redirect_to view_study_path(@study.url_safe_name), alert: 'You have exceeded your current daily download quota.  You must wait until tomorrow to download this file.' and return
      end
    rescue RuntimeError => e
      logger.error "#{Time.now}: error generating signed url for #{params[:filename]}; #{e.message}"
      redirect_to view_study_path(@study.url_safe_name), alert: "We were unable to download the file #{params[:filename]} do to an error: #{e.message}" and return
    end
    # redirect directly to file to trigger download
    redirect_to @signed_url
  end

  # search for one or more genes to view expression information
  # will redirect to appropriate method as needed
  def search_genes
    if params[:search][:upload].blank?
      terms = parse_search_terms(:genes)
      @genes = load_expression_scores(terms)
    else
      geneset_file = params[:search][:upload]
      terms = geneset_file.read.split(/[\s\r\n?,]/).map {|gene| gene.strip}
      @genes = load_expression_scores(terms)
    end
    # grab saved params for loaded cluster, boxpoints mode, annotations and consensus
    cluster = params[:search][:cluster]
    annotation = params[:search][:annotation]
    boxpoints = params[:search][:boxpoints]
    consensus = params[:search][:consensus]
    subsample = params[:search][:subsample]

    # check if one gene was searched for, but more than one found
    # we can assume that in this case there is an exact match possible
    # cast as an array so block after still works properly
    if @genes.size > 1 && terms.size == 1
      @genes = [load_best_gene_match(@genes, terms.first)]
    end

    # determine which view to load
    if @genes.empty?
      redirect_to request.referrer, alert: "No matches found for: #{terms.join(', ')}."
    elsif @genes.size > 1 && !consensus.blank?
      redirect_to view_gene_set_expression_path(study_name: params[:study_name], search: {genes: terms.join(' ')} , cluster: cluster, annotation: annotation, consensus: consensus, subsample: subsample)
    elsif @genes.size > 1 && consensus.blank?
      redirect_to view_gene_expression_heatmap_path(search: {genes: terms.join(' ')}, cluster: cluster, annotation: annotation)
    else
      gene = @genes.first
      redirect_to view_gene_expression_path(study_name: params[:study_name], gene: gene.gene, cluster: cluster, boxpoints: boxpoints, annotation: annotation, consensus: consensus, subsample: subsample)
    end
  end

  # render box and scatter plots for parent clusters or a particular sub cluster
  def view_gene_expression
    @options = load_cluster_group_options
    @cluster_annotations = load_cluster_group_annotations
    @top_plot_partial = @selected_annotation[:type] == 'group' ? 'expression_plots_view' : 'expression_annotation_plots_view'
    @y_axis_title = load_expression_axis_title
  end

  # re-renders plots when changing cluster selection
  def render_gene_expression_plots
    matches = @study.expression_scores.by_gene(params[:gene])
    subsample = params[:subsample].blank? ? nil : params[:subsample].to_i
    @gene = load_best_gene_match(matches, params[:gene])
    @y_axis_title = load_expression_axis_title
    # depending on annotation type selection, set up necessary partial names to use in rendering
    if @selected_annotation[:type] == 'group'
      @values = load_expression_boxplot_data_array_scores(@selected_annotation, subsample)
      if params[:plot_type] == 'box'
        @values_box_type = 'box'
      else
        @values_box_type = 'violin'
        @values_kernel_type = params[:kernel_type]
        @values_band_type = params[:band_type]
      end
      @top_plot_partial = 'expression_plots_view'
      @top_plot_plotly = 'expression_plots_plotly'
      @top_plot_layout = 'expression_box_layout'
    else
      @values = load_annotation_based_data_array_scatter(@selected_annotation, subsample)
      @top_plot_partial = 'expression_annotation_plots_view'
      @top_plot_plotly = 'expression_annotation_plots_plotly'
      @top_plot_layout = 'expression_annotation_scatter_layout'
      @annotation_scatter_range = set_range(@values.values)
    end
    @expression = load_expression_data_array_points(@selected_annotation, subsample)
    @options = load_cluster_group_options
    @range = set_range([@expression[:all]])
    @coordinates = load_cluster_group_data_array_points(@selected_annotation, subsample)
    @static_range = set_range(@coordinates.values)
    if @cluster.is_3d? && @cluster.has_range?
      @expression_aspect = compute_aspect_ratios(@range)
      @static_aspect = compute_aspect_ratios(@static_range)
    end
    @cluster_annotations = load_cluster_group_annotations

    # load default color profile if necessary
    if params[:annotation] == @study.default_annotation && @study.default_annotation_type == 'numeric' && !@study.default_color_profile.nil?
      @expression[:all][:marker][:colorscale] = @study.default_color_profile
      @coordinates[:all][:marker][:colorscale] = @study.default_color_profile
    end
  end

  # view set of genes (scores averaged) as box and scatter plots
  # works for both a precomputed list (study supplied) or a user query
  def view_gene_set_expression
    # first check if there is a user-supplied gene list to view as consensus
    # call search_expression_scores to return values not found
    if params[:genes_set].nil? && !params[:consensus].blank?
      terms = parse_search_terms(:genes)
      @genes, @not_found = search_expression_scores(terms)
    else
      precomputed = @study.precomputed_scores.by_name(params[:gene_set])
      @genes = []
      precomputed.gene_list.each do |gene|
        matches = @study.expression_scores.by_gene(gene)
        matches.map {|gene| @genes << gene}
      end
    end
    consensus = params[:consensus].nil? ? 'Mean ' : params[:consensus].capitalize + ' '
    @gene_list = @genes.map(&:gene).join(' ')
    @y_axis_title = consensus + ' ' + load_expression_axis_title
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
    # first check if there is a user-supplied gene list to view as consensus
    # call load expression scores since we know genes exist already from view_gene_set_expression

    if params[:gene_set].nil?
      terms = parse_search_terms(:genes)
      @genes = load_expression_scores(terms)
    else
      precomputed = @study.precomputed_scores.by_name(params[:gene_set])
      @genes = []
      precomputed.gene_list.each do |gene|
        matches = @study.expression_scores.by_gene(gene)
        matches.map {|gene| @genes << gene}
      end
    end
    subsample = params[:subsample].blank? ? nil : params[:subsample].to_i
    consensus = params[:consensus].nil? ? 'Mean ' : params[:consensus].capitalize + ' '
    @gene_list = @genes.map(&:gene).join(' ')
    @y_axis_title = consensus + ' ' + load_expression_axis_title
    # depending on annotation type selection, set up necessary partial names to use in rendering
    if @selected_annotation[:type] == 'group'
      @values = load_gene_set_expression_boxplot_scores(@selected_annotation, params[:consensus], subsample)
      if params[:plot_type] == 'box'
        @values_box_type = 'box'
      else
        @values_box_type = 'violin'
        @values_kernel_type = params[:kernel_type]
        @values_band_type = params[:band_type]
      end
      @top_plot_partial = 'expression_plots_view'
      @top_plot_plotly = 'expression_plots_plotly'
      @top_plot_layout = 'expression_box_layout'
    else
      @values = load_gene_set_annotation_based_scatter(@selected_annotation, params[:consensus], subsample)
      @top_plot_partial = 'expression_annotation_plots_view'
      @top_plot_plotly = 'expression_annotation_plots_plotly'
      @top_plot_layout = 'expression_annotation_scatter_layout'
      @annotation_scatter_range = set_range(@values.values)
    end
    # load expression scatter using main gene expression values
    @expression = load_gene_set_expression_data_arrays(@selected_annotation, params[:consensus], subsample)
    color_minmax =  @expression[:all][:marker][:color].minmax
    @expression[:all][:marker][:cmin], @expression[:all][:marker][:cmax] = color_minmax

    # load static cluster reference plot
    @coordinates = load_cluster_group_data_array_points(@selected_annotation, subsample)
    # set up options, annotations and ranges
    @options = load_cluster_group_options
    @range = set_range([@expression[:all]])
    @static_range = set_range(@coordinates.values)

    if @cluster.is_3d? && @cluster.has_range?
      @expression_aspect = compute_aspect_ratios(@range)
      @static_aspect = compute_aspect_ratios(@static_range)
    end

    @cluster_annotations = load_cluster_group_annotations

    if @genes.size > 5
      @main_genes, @other_genes = divide_genes_for_header
    end

    # load default color profile if necessary
    if params[:annotation] == @study.default_annotation && @study.default_annotation_type == 'numeric' && !@study.default_color_profile.nil?
      @expression[:all][:marker][:colorscale] = @study.default_color_profile
      @coordinates[:all][:marker][:colorscale] = @study.default_color_profile
    end

    render 'render_gene_expression_plots'
  end

  # view genes in Morpheus as heatmap
  def view_gene_expression_heatmap
    # parse and divide up genes
    terms = parse_search_terms(:genes)
    @genes, @not_found = search_expression_scores(terms)
    @gene_list = @genes.map(&:gene).join(' ')
    # load dropdown options
    @options = load_cluster_group_options
    @cluster_annotations = load_cluster_group_annotations
    if @genes.size > 5
      @main_genes, @other_genes = divide_genes_for_header
    end

  end

  # load data in gct form to render in Morpheus, preserving query order
  def expression_query
    if check_xhr_view_permissions
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
    else
      head 403
    end
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
    if check_xhr_view_permissions
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
    else
      head 403
    end
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
    # check if FireCloud is available first
    @allow_downloads = Study.firecloud_client.api_available?
    @disabled_link = "<button type='button' class='btn btn-danger' disabled>Currently Unavailable</button>".html_safe
    # load study_file fastqs first
    @fastq_files = {data: []}
    @study.study_files.by_type('Fastq').each do |file|
      link = view_context.link_to("<span class='fa fa-download'></span> #{view_context.number_to_human_size(file.upload_file_size, prefix: :si)}".html_safe, file.download_path, class: "btn btn-primary dl-link fastq", download: file.upload_file_name)
      @fastq_files[:data] << [
          file.name,
          file.description,
          @allow_downloads ? link : @disabled_link
      ]
    end
    # now load fastq's from directory_listings (only synced directories)
    @study.directory_listings.where(sync_status: true).each do |directory|
      directory.files.each do |file|
        basename = file[:name].split('/').last
        link = view_context.link_to("<span class='fa fa-download'></span> #{view_context.number_to_human_size(file[:size], prefix: :si)}".html_safe, directory.download_path(file[:name]), class: "btn btn-primary dl-link fastq", download: basename)
        @fastq_files[:data] << [
            file[:name],
            directory.description,
            @allow_downloads ? link : @disabled_link
        ]
      end
    end
    render json: @fastq_files.to_json
  end

  def create_user_annotations
    @data_names = []

    begin
      user_annotation_params[:user_data_arrays_attributes].keys.each do |key|
        user_annotation_params[:user_data_arrays_attributes][key][:values] =  user_annotation_params[:user_data_arrays_attributes][key][:values].split(',')
        @data_names.push(user_annotation_params[:user_data_arrays_attributes][key][:name].strip )
      end

      @user_annotation = UserAnnotation.new(user_id: user_annotation_params[:user_id], study_id: user_annotation_params[:study_id], cluster_group_id: user_annotation_params[:cluster_group_id], values: @data_names, name: user_annotation_params[:name])

      if @user_annotation.save
        @user_annotation.initialize_user_data_arrays(user_annotation_params[:user_data_arrays_attributes], user_annotation_params[:subsample_annotation],user_annotation_params[:subsample_threshold], user_annotation_params[:loaded_annotation])
        @cluster_annotations = load_cluster_group_annotations
        @options = load_cluster_group_options
        @alert = nil
        @notice = 'User Annotation successfully saved. You may now view this annotation via the annotations dropdown.'
        render 'update_user_clusters'
      else
        logger.info('Error Saving User Annotation')
        @cluster_annotations = load_cluster_group_annotations
        @options = load_cluster_group_options
        @notice = nil
        @alert = 'The following errors prevented the annotation from being saved: ' + @user_annotation.errors.full_messages.join(',')
        render 'update_user_clusters'
      end
    rescue Mongoid::Errors::InvalidValue => e
      @cluster_annotations = load_cluster_group_annotations
      @options = load_cluster_group_options
      @notice = nil
      @alert = 'The following errors prevented the annotation from being saved: ' + 'Invalid data type submitted. (' + e.problem + '. ' + e.resolution + ')'
      render 'update_user_clusters'

    rescue NoMethodError => e
      @cluster_annotations = load_cluster_group_annotations
      @options = load_cluster_group_options
      @notice = nil
      @alert = 'The following errors prevented the annotation from being saved: ' + e.message
      render 'update_user_clusters'


    rescue => e
      @cluster_annotations = load_cluster_group_annotations
      @options = load_cluster_group_options
      @notice = nil
      @alert = 'An unexpected error prevented the annotation from being saved: ' + e.message
      render 'update_user_clusters'
    end
  end

  private

  # SETTERS
  def set_study
    @study = Study.where(url_safe_name: params[:study_name]).first
  end

  def set_cluster_group
    # determine which URL param to use for selection
    selector = params[:cluster].nil? ? params[:gene_set_cluster] : params[:cluster]
    if selector.nil? || selector.empty?
      @cluster = @study.default_cluster
    else
      @cluster = @study.cluster_groups.by_name(selector)
    end
  end

  def set_selected_annotation
    # determine which URL param to use for selection and construct base object
    selector = params[:annotation].nil? ? params[:gene_set_annotation] : params[:annotation]
    annot_name, annot_type, annot_scope = selector.nil? ? @study.default_annotation.split('--') : selector.split('--')
    # construct object based on name, type & scope
    if annot_scope == 'cluster'
      @selected_annotation = @cluster.cell_annotations.find {|ca| ca[:name] == annot_name && ca[:type] == annot_type}
      @selected_annotation[:scope] = annot_scope
    elsif annot_scope == 'user'
      user_annotation = @cluster.user_annotations.by_name_and_user(annot_name, current_user.id)
      @selected_annotation = {name: annot_name, type: annot_type, scope: annot_scope}
      @selected_annotation[:values] = user_annotation.values
    else
      @selected_annotation = {name: annot_name, type: annot_type, scope: annot_scope}
      if annot_type == 'group'
        @selected_annotation[:values] = @study.study_metadata_keys(annot_name, annot_type)
      end
    end
    @selected_annotation
  end

  # whitelist parameters for updating studies on study settings tab (smaller list than in studies controller)
  def study_params
    params.require(:study).permit(:name, :description, :public, :embargo, :default_options => [:cluster, :annotation, :color_profile], study_shares_attributes: [:id, :_destroy, :email, :permission])
  end

  # whitelist parameters for creating custom user annotation
  def user_annotation_params
    params.require(:user_annotation).permit(:_id, :name, :study_id, :user_id, :cluster_group_id, :subsample_threshold, :loaded_annotation, :subsample_annotation, user_data_arrays_attributes: [:name, :values])
  end

  def check_view_permissions
    unless @study.public?
      if (!user_signed_in? && !@study.public?) || (user_signed_in? && !@study.can_view?(current_user))
        redirect_to site_path, alert: 'You do not have permission to view the requested page.' and return
      end
    end
  end

  # check permissions manually on AJAX call via authentication token
  def check_xhr_view_permissions
    unless @study.public?
      if params[:request_user_token].nil?
        return false
      else
        request_user_id, auth_token = params[:request_user_token].split(':')
        request_user = User.find_by(id: request_user_id, authentication_token: auth_token)
        unless !request_user.nil? && @study.can_view?(request_user)
          return false
        end
      end
      return true
    else
      return true
    end
  end

	# SUB METHODS

  # generic method to populate data structure to render a cluster scatter plot
  # uses cluster_group model and loads annotation for both group & numeric plots
  # data values are pulled from associated data_array entries for each axis and annotation/text value
  def load_cluster_group_data_array_points(annotation, subsample_threshold=nil)
    # construct annotation key to load subsample data_arrays if needed, will be identical to params[:annotation]
    subsample_annotation = "#{annotation[:name]}--#{annotation[:type]}--#{annotation[:scope]}"
    # load data - passing nil for subsample_threshold automatically loads all values
    x_array = @cluster.concatenate_data_arrays('x', 'coordinates', subsample_threshold, subsample_annotation)
    y_array = @cluster.concatenate_data_arrays('y', 'coordinates', subsample_threshold, subsample_annotation)
    z_array = @cluster.concatenate_data_arrays('z', 'coordinates', subsample_threshold, subsample_annotation)
    cells = @cluster.concatenate_data_arrays('text', 'cells', subsample_threshold, subsample_annotation)
    annotation_array = []
    annotation_hash = {}
    if annotation[:scope] == 'cluster'
      annotation_array = @cluster.concatenate_data_arrays(annotation[:name], 'annotations', subsample_threshold, subsample_annotation)
    elsif annotation[:scope] == 'user'
      user_annotation = @cluster.user_annotations.by_name_and_user(annotation[:name], current_user.id)
      annotation_array = user_annotation.concatenate_user_data_arrays(annotation[:name], 'annotations', subsample_threshold, subsample_annotation)
      x_array = user_annotation.concatenate_user_data_arrays('x', 'coordinates', subsample_threshold, subsample_annotation)
      y_array = user_annotation.concatenate_user_data_arrays('y', 'coordinates', subsample_threshold, subsample_annotation)
      z_array = user_annotation.concatenate_user_data_arrays('z', 'coordinates', subsample_threshold, subsample_annotation)
      cells = user_annotation.concatenate_user_data_arrays('text', 'cells', subsample_threshold, subsample_annotation)
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
          annotations: annotation[:scope] == 'cluster' ? annotation_array : annotation_hash[:values],
          text: text_array,
          cells: cells,
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
      if @cluster.is_3d?
        coordinates[:all][:z] = z_array
      end
    else
      # assemble containers for each trace
      annotation[:values].each do |value|
        coordinates[value] = {x: [], y: [], text: [], cells: [], annotations: [], name: "#{annotation[:name]}: #{value}", marker_size: []}
        if @cluster.is_3d?
          coordinates[value][:z] = []
        end
      end

      if annotation[:scope] == 'cluster' || annotation[:scope] == 'user'
        annotation_array.each_with_index do |annotation_value, index|

          coordinates[annotation_value][:text] << "<b>#{cells[index]}</b><br>#{annotation[:name]}: #{annotation_value}"
          coordinates[annotation_value][:annotations] << "#{annotation[:name]}: #{annotation_value}"
          coordinates[annotation_value][:cells] << cells[index]
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
            coordinates[annotation_value][:annotations] << "#{annotation[:name]}: #{annotation_value}"
            coordinates[annotation_value][:x] << x_array[index]
            coordinates[annotation_value][:y] << y_array[index]
            coordinates[annotation_value][:cells] << cell
            if @cluster.cluster_type == '3d'
              coordinates[annotation_value][:z] << z_array[index]
            end
            coordinates[annotation_value][:marker_size] << 6
          end
        end
        coordinates.each do |key, data|
          data[:name] << " (#{data[:x].size} points)"
        end

      end

    end
    # gotcha to remove entries in case a particular annotation value comes up blank since this is study-wide
    coordinates.delete_if {|key, data| data[:x].empty?}
    coordinates
  end

  # method to load a 2-d scatter of selected numeric annotation vs. gene expression
  def load_annotation_based_data_array_scatter(annotation, subsample_threshold=nil)
    # construct annotation key to load subsample data_arrays if needed, will be identical to params[:annotation]
    subsample_annotation = "#{annotation[:name]}--#{annotation[:type]}--#{annotation[:scope]}"
    cells = @cluster.concatenate_data_arrays('text', 'cells', subsample_threshold, subsample_annotation)
    annotation_array = []
    annotation_hash = {}
    if annotation[:scope] == 'cluster'
      annotation_array = @cluster.concatenate_data_arrays(annotation[:name], 'annotations', subsample_threshold, subsample_annotation)
    elsif annotation[:scope] == 'user'
      user_annotation = @cluster.user_annotations.by_name_and_user(annotation[:name], current_user.id)
      annotation_array = user_annotation.concatenate_user_data_arrays(annotation[:name], 'annotations', subsample_threshold, subsample_annotation)
      cells = user_annotation.concatenate_user_data_arrays('text', 'cells', subsample_threshold, subsample_annotation)
    else
      annotation_hash = @study.study_metadata_values(annotation[:name], annotation[:type])
    end
    values = {}
    if annotation[:scope] == 'cluster' || annotation[:scope] == 'user'
      annotation_array.each_with_index do |annot, index|
        annotation_value = annot
        cell_name = cells[index]
        expression_value = @gene.scores[cell_name].to_f.round(4)
        values[:all][:text] << "<b>#{cell_name}</b><br>#{annotation[:name]}: #{annotation_value}<br>#{@y_axis_title}: #{expression_value}"
        values[:all][:annotations] << "#{annotation[:name]}: #{annotation_value}"
        values[:all][:x] << annotation_value
        values[:all][:y] << expression_value
        values[:all][:cells] << cell_name
        values[:all][:marker_size] << 6
      end
    else
      cells.each do |cell|
        if annotation_hash.has_key?(cell)
          annotation_value = annotation_hash[cell]
          expression_value = @gene.scores[cell].to_f.round(4)
          values[:all][:text] << "<b>#{cell}</b><br>#{annotation[:name]}: #{annotation_value}<br>#{@y_axis_title}: #{expression_value}"
          values[:all][:annotations] << "#{annotation[:name]}: #{annotation_value}"
          values[:all][:x] << annotation_value
          values[:all][:y] << expression_value
          values[:all][:cells] << cell
          values[:all][:marker_size] << 6
        end
      end
    end
    values
  end

  # method to load a 2-d scatter of selected numeric annotation vs. gene set expression
  # will support a variety of consensus modes (default is mean)
  def load_gene_set_annotation_based_scatter(annotation, consensus, subsample_threshold=nil)
    # construct annotation key to load subsample data_arrays if needed, will be identical to params[:annotation]
    subsample_annotation = "#{annotation[:name]}--#{annotation[:type]}--#{annotation[:scope]}"
    values = {}
    values[:all] = {x: [], y: [], cells: [], anotations: [], text: [], marker_size: []}
    cells = @cluster.concatenate_data_arrays('text', 'cells', subsample_threshold, subsample_annotation)
    annotation_array = []
    annotation_hash = {}
    if annotation[:scope] == 'cluster'
      annotation_array = @cluster.concatenate_data_arrays(annotation[:name], 'annotations', subsample_threshold, subsample_annotation)
    elsif annotation[:scope] == 'user'
      user_annotation = @cluster.user_annotations.by_name_and_user(annotation[:name], current_user.id)
      annotation_array = user_annotation.concatenate_user_data_arrays(annotation[:name], 'annotations', subsample_threshold, subsample_annotation)
      cells = user_annotation.concatenate_user_data_arrays('text', 'cells', subsample_threshold, subsample_annotation)
    else
      annotation_hash = @study.study_metadata_values(annotation[:name], annotation[:type])
    end
    cells.each_with_index do |cell|
      annotation_value = annotation[:scope] == 'cluster' ? annotation_array[index] : annotation_hash[cell]
      case consensus
        when 'mean'
          expression_value = calculate_mean(@genes, cell)
        when 'median'
          expression_value = calculate_median(@genes, cell)
        else
          expression_value = calculate_mean(@genes, cell)
      end
      values[:all][:text] << "<b>#{cell}</b><br>#{annotation[:name]}: #{annotation_value}<br>#{@y_axis_title}: #{expression_value}"
      values[:all][:annotations] << "#{annotation[:name]}: #{annotation_value}"
      values[:all][:x] << annotation_value
      values[:all][:y] << expression_value
      values[:all][:cells] << cell
      values[:all][:marker_size] << 6
    end
    values
  end

  # load box plot scores from gene expression values using data array of cell names for given cluster
  def load_expression_boxplot_data_array_scores(annotation, subsample_threshold=nil)
    # construct annotation key to load subsample data_arrays if needed, will be identical to params[:annotation]
    subsample_annotation = "#{annotation[:name]}--#{annotation[:type]}--#{annotation[:scope]}"
    values = initialize_plotly_objects_by_annotation(annotation)

    # grab all cells present in the cluster, and use as keys to load expression scores
    # if a cell is not present for the gene, score gets set as 0.0
    cells = @cluster.concatenate_data_arrays('text', 'cells', subsample_threshold, subsample_annotation)
    if annotation[:scope] == 'cluster'
      # we can take a subsample of the same size for the annotations since the sort order is non-stochastic (i.e. the indices chosen are the same every time for all arrays)
      annotations = @cluster.concatenate_data_arrays(annotation[:name], 'annotations', subsample_threshold, subsample_annotation)
      cells.each_with_index do |cell, index|
        values[annotations[index]][:y] << @gene.scores[cell].to_f.round(4)
      end
    elsif annotation[:scope] == 'user'
      user_annotation = @cluster.user_annotations.by_name_and_user(annotation[:name], current_user.id)
      annotations = user_annotation.concatenate_user_data_arrays(annotation[:name], 'annotations', subsample_threshold, subsample_annotation)
      cells = user_annotation.concatenate_user_data_arrays('text', 'cells', subsample_threshold, subsample_annotation)
      cells.each_with_index do |cell, index|
        values[annotations[index]][:y] << @gene.scores[cell].to_f.round(4)
      end
    else
      # since annotations are in a hash format, subsampling isn't necessary as we're going to retrieve values by key lookup
      annotations =  @study.study_metadata_values(annotation[:name], annotation[:type])
      cells.each do |cell|
        val = annotations[cell]
        # must check if key exists
        if values.has_key?(val)
          values[annotations[cell]][:y] << @gene.scores[cell].to_f.round(4)
          values[annotations[cell]][:cells] << cell
        end
      end
    end
    # remove any empty values as annotations may have created keys that don't exist in cluster
    values.delete_if {|key, data| data[:y].empty?}
    values
  end

  # load cluster_group data_array values, but use expression scores to set numerical color array
  def load_expression_data_array_points(annotation, subsample_threshold=nil)
    # construct annotation key to load subsample data_arrays if needed, will be identical to params[:annotation]
    subsample_annotation = "#{annotation[:name]}--#{annotation[:type]}--#{annotation[:scope]}"
    x_array = @cluster.concatenate_data_arrays('x', 'coordinates', subsample_threshold, subsample_annotation)
    y_array = @cluster.concatenate_data_arrays('y', 'coordinates', subsample_threshold, subsample_annotation)
    z_array = @cluster.concatenate_data_arrays('z', 'coordinates', subsample_threshold, subsample_annotation)
    cells = @cluster.concatenate_data_arrays('text', 'cells', subsample_threshold, subsample_annotation)
    annotation_array = []
    annotation_hash = {}
    if annotation[:scope] == 'cluster'
      annotation_array = @cluster.concatenate_data_arrays(annotation[:name], 'annotations', subsample_threshold)
    elsif annotation[:scope] == 'user'
      user_annotation = @cluster.user_annotations.by_name_and_user(annotation[:name], current_user.id)
      annotation_array = user_annotation.concatenate_user_data_arrays(annotation[:name], 'annotations', subsample_threshold, subsample_annotation)
      x_array = user_annotation.concatenate_user_data_arrays('x', 'coordinates', subsample_threshold, subsample_annotation)
      y_array = user_annotation.concatenate_user_data_arrays('y', 'coordinates', subsample_threshold, subsample_annotation)
      z_array = user_annotation.concatenate_user_data_arrays('z', 'coordinates', subsample_threshold, subsample_annotation)
      cells = user_annotation.concatenate_user_data_arrays('text', 'cells', subsample_threshold, subsample_annotation)
    else
      # for study-wide annotations, load from study_metadata values instead of cluster-specific annotations
      annotation_hash = @study.study_metadata_values(annotation[:name], annotation[:type])
    end
    expression = {}
    expression[:all] = {
        x: x_array,
        y: y_array,
        annotations: [],
        text: [],
        cells: cells,
        marker: {cmax: 0, cmin: 0, color: [], size: [], showscale: true, colorbar: {title: @y_axis_title , titleside: 'right'}}
    }
    if @cluster.is_3d?
      expression[:all][:z] = z_array
    end
    cells.each_with_index do |cell, index|
      expression_score = @gene.scores[cell].to_f.round(4)
      # load correct annotation value based on scope
      annotation_value = annotation[:scope] == 'cluster' ? annotation_array[index] : annotation_hash[cell]
      text_value = "#{cell} (#{annotation[:name]}: #{annotation_value})<br />#{@y_axis_title}: #{expression_score}"
      expression[:all][:annotations] << "#{annotation[:name]}: #{annotation_value}"
      expression[:all][:text] << text_value
      expression[:all][:marker][:color] << expression_score
      expression[:all][:marker][:size] << 6
    end
    color_minmax =  expression[:all][:marker][:color].minmax
    expression[:all][:marker][:cmin], expression[:all][:marker][:cmax] = color_minmax
    expression[:all][:marker][:colorscale] = 'Reds'
    expression
  end

  # load boxplot expression scores vs. scores across each gene for all cells
  # will support a variety of consensus modes (default is mean)
  def load_gene_set_expression_boxplot_scores(annotation, consensus, subsample_threshold=nil)
		values = initialize_plotly_objects_by_annotation(annotation)
    # construct annotation key to load subsample data_arrays if needed, will be identical to params[:annotation]
    subsample_annotation = "#{annotation[:name]}--#{annotation[:type]}--#{annotation[:scope]}"
    logger.info('LOOK!')
    # grab all cells present in the cluster, and use as keys to load expression scores
    # if a cell is not present for the gene, score gets set as 0.0
    # will check if there are more than SUBSAMPLE_THRESHOLD cells present in the cluster, and subsample accordingly
    # values hash will be assembled differently depending on annotation scope (cluster-based is array, study-based is a hash)
    cells = @cluster.concatenate_data_arrays('text', 'cells', subsample_threshold, subsample_annotation)
    if annotation[:scope] == 'cluster'
      annotations = @cluster.concatenate_data_arrays(annotation[:name], 'annotations', subsample_threshold, subsample_annotation)
      cells.each_with_index do |cell, index|
        values[annotations[index]][:annotations] << annotations[index]
        case consensus
          when 'mean'
            values[annotations[index]][:y] << calculate_mean(@genes, cell)
          when 'median'
            values[annotations[index]][:y] << calculate_median(@genes, cell)
          else
            values[annotations[index]][:y] << calculate_mean(@genes, cell)
        end
      end
    elsif annotation[:scope] == 'user'
      user_annotation = @cluster.user_annotations.by_name_and_user(annotation[:name], current_user.id)
      annotations = user_annotation.concatenate_user_data_arrays(annotation[:name], 'annotations', subsample_threshold, subsample_annotation)
      cells = user_annotation.concatenate_user_data_arrays('text', 'cells', subsample_threshold, subsample_annotation)
      cells.each_with_index do |cell, index|
        values[annotations[index]][:annotations] << annotations[index]
        case consensus
          when 'mean'
            values[annotations[index]][:y] << calculate_mean(@genes, cell)
          when 'median'
            values[annotations[index]][:y] << calculate_median(@genes, cell)
          else
            values[annotations[index]][:y] << calculate_mean(@genes, cell)
        end
      end
    else
      # no need to subsample annotation since they are in hash format (lookup done by key)
      annotations = @study.study_metadata_values(annotation[:name], annotation[:type])
      cells.each do |cell|
        val = annotations[cell]
        # must check if key exists
        if values.has_key?(val)
          values[annotations[cell]][:cells] << cell
          case consensus
            when 'mean'
              values[annotations[cell]][:y] << calculate_mean(@genes, cell)
            when 'median'
              values[annotations[cell]][:y] << calculate_median(@genes, cell)
            else
              values[annotations[cell]][:y] << calculate_mean(@genes, cell)
          end
        end
      end
      # remove any empty values as annotations may have created keys that don't exist in cluster
      logger.info("Look: #{annotation[:scope]}")
    end
    values.delete_if {|key, data| data[:y].empty?}
    values
  end

  # load scatter expression scores with average of scores across each gene for all cells
	# uses data_array as source for each axis
  # will support a variety of consensus modes (default is mean)
	def load_gene_set_expression_data_arrays(annotation, consensus, subsample_threshold=nil)
    # construct annotation key to load subsample data_arrays if needed, will be identical to params[:annotation]
    subsample_annotation = "#{annotation[:name]}--#{annotation[:type]}--#{annotation[:scope]}"

    x_array = @cluster.concatenate_data_arrays('x', 'coordinates', subsample_threshold, subsample_annotation)
    y_array = @cluster.concatenate_data_arrays('y', 'coordinates', subsample_threshold, subsample_annotation)
    z_array = @cluster.concatenate_data_arrays('z', 'coordinates', subsample_threshold, subsample_annotation)
    cells = @cluster.concatenate_data_arrays('text', 'cells', subsample_threshold, subsample_annotation)
    annotation_array = []
    annotation_hash = {}
    if annotation[:scope] == 'cluster'
      annotation_array = @cluster.concatenate_data_arrays(annotation[:name], 'annotations', subsample_threshold, subsample_annotation)
    elsif annotation[:scope] == 'user'
      user_annotation = @cluster.user_annotations.by_name_and_user(annotation[:name], current_user.id)
      annotation_array = user_annotation.concatenate_user_data_arrays(annotation[:name], 'annotations', subsample_threshold, subsample_annotation)
      x_array = user_annotation.concatenate_user_data_arrays('x', 'coordinates', subsample_threshold, subsample_annotation)
      y_array = user_annotation.concatenate_user_data_arrays('y', 'coordinates', subsample_threshold, subsample_annotation)
      z_array = user_annotation.concatenate_user_data_arrays('z', 'coordinates', subsample_threshold, subsample_annotation)
      cells = user_annotation.concatenate_user_data_arrays('text', 'cells', subsample_threshold, subsample_annotation)
    else
      # for study-wide annotations, load from study_metadata values instead of cluster-specific annotations
      annotation_hash = @study.study_metadata_values(annotation[:name], annotation[:type])
    end
		expression = {}
		expression[:all] = {
				x: x_array,
				y: y_array,
				text: [],
        annotations: [],
        cells: cells,
				marker: {cmax: 0, cmin: 0, color: [], size: [], showscale: true, colorbar: {title: @y_axis_title , titleside: 'right'}}
		}
    if @cluster.is_3d?
      expression[:all][:z] = z_array
    end
		cells.each_with_index do |cell, index|
      case consensus
        when 'mean'
          expression_score = calculate_mean(@genes, cell)
        when 'median'
          expression_score = calculate_median(@genes, cell)
        else
          expression_score = calculate_mean(@genes, cell)
      end

      # load correct annotation value based on scope
      annotation_value = annotation[:scope] == 'cluster' ? annotation_array[index] : annotation_hash[cell]
      text_value = "#{cell} (#{annotation[:name]}: #{annotation_value})<br />#{@y_axis_title}: #{expression_score}"
			expression[:all][:annotations] << "#{annotation[:name]}: #{annotation_value}"
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
      values["#{value}"] = {y: [], cells: [], annotations: [], name: "#{value}" }
    end
    logger.info("Values: #{values}")
    values
  end

  # find mean of expression scores for a given cell & list of genes
  def calculate_mean(genes, cell)
    sum = 0.0
    genes.each do |gene|
      sum += gene.scores[cell].to_f
    end
    sum / genes.size
  end

  # find median expression score for a given cell & list of genes
  def calculate_median(genes, cell)
    gene_scores = []
    genes.each do |gene|
      gene_scores << gene.scores[cell].to_f
    end
    sorted = gene_scores.sort
    len = sorted.length
    (sorted[(len - 1) / 2] + sorted[len / 2]) / 2.0
  end

  # generic search term parser
  def parse_search_terms(key)
    terms = params[:search][key]
    if terms.is_a?(Array)
      terms.first.split(/[\s\n,]/).map(&:strip)
    else
      terms.split(/[\s\n,]/).map(&:strip)
    end
  end

  # generic expression score getter, preserves order and discards empty matches
  def load_expression_scores(terms)
    genes = []
    terms.each do |term|
      matches = @study.expression_scores.by_gene(term)
      unless matches.empty?
        genes << load_best_gene_match(matches, term)
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
        genes << load_best_gene_match(matches, term)
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
    # go through a second time to see if there is a case-insensitive match by looking at searchable_gene
    # this is done after a complete iteration to ensure that there wasn't an exact match available
    matches.each do |match|
      if match.searchable_gene == search_term.downcase
        return match
      end
    end
  end

  # helper method to load all possible cluster groups for a study
  def load_cluster_group_options
    @study.cluster_groups.map(&:name)
  end

  # helper method to load all available cluster_group-specific annotations
  def load_cluster_group_annotations
    grouped_options = {
        'Cluster-based' => @cluster.cell_annotations.map {|annot| ["#{annot[:name]}", "#{annot[:name]}--#{annot[:type]}--cluster"]},
        'Study Wide' => @study.study_metadata.map {|metadata| ["#{metadata.name}", "#{metadata.name}--#{metadata.annotation_type}--study"] }.uniq
    }
    if user_signed_in?
      user_annotations = UserAnnotation.where(user_id: current_user.id, study_id: @study.id, cluster_group_id: @cluster.id).to_a
      unless user_annotations.empty?
        grouped_options['User Annotations'] = user_annotations.map {|annot| ["#{annot.name}", "#{annot.name}--group--user"] }
      end
    end
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
  # dynamically determines range based on inputs & available axes
  def set_range(inputs)
    # select coordinate axes from inputs
    domain_keys = inputs.map(&:keys).flatten.uniq.select {|i| [:x, :y, :z].include?(i)}
    range = Hash[domain_keys.zip]
    if @cluster.has_range?
      # use study-provided range if available
      range = @cluster.domain_ranges
    else
      # take the minmax of each domain across all groups, then the global minmax
      @vals = inputs.map {|v| domain_keys.map {|k| v[k].minmax}}.flatten.minmax
      # add 2% padding to range
      scope = (@vals.first - @vals.last) * 0.02
      raw_range = [@vals.first + scope, @vals.last - scope]
      range[:x] = raw_range
      range[:y] = raw_range
      range[:z] = raw_range
    end
    range
  end

  # compute the aspect ratio between all ranges and use to enforce equal-aspect ranges on 3d plots
  def compute_aspect_ratios(range)
    # determine largest range for computing aspect ratio
    extent = {}
    range.each.map {|axis, domain| extent[axis] = domain.first.upto(domain.last).size - 1}
    largest_range = extent.values.max

    # now compute aspect mode and ratios
    aspect = {
        mode: extent.values.uniq.size == 1 ? 'cube' : 'manual'
    }
    range.each_key do |axis|
      aspect[axis.to_sym] = extent[axis].to_f / largest_range
    end
    aspect
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

  def load_expression_axis_title
    @study.expression_matrix_file.y_axis_label.empty? ? 'Expression' : @study.expression_matrix_file.y_axis_label
  end

  # create a unique hex digest of a list of genes for use in set_cache_path
  def construct_gene_list_hash(query_list)
    genes = query_list.split.map(&:strip).sort.join
    Digest::SHA256.hexdigest genes
  end

  protected

  # construct a path to store cache results based on query parameters
  def set_cache_path
    params_key = "_#{params[:cluster].to_s.split.join('-')}_#{params[:annotation]}"
    case action_name
      when 'render_cluster'
        unless params[:subsample].nil?
          params_key += "_#{params[:subsample]}"
        end
        render_cluster_url(study_name: params[:study_name]) + params_key
      when 'render_gene_expression_plots'
        unless params[:subsample].nil?
          params_key += "_#{params[:subsample]}"
        end
        params_key += "_#{params[:plot_type]}"
        unless params[:kernel_type].nil?
          params_key += "_#{params[:kernel_type]}"
        end
        unless params[:band_type].nil?
          params_key += "_#{params[:band_type]}"
        end
        render_gene_expression_plots_url(study_name: params[:study_name], gene: params[:gene]) + params_key
      when 'render_gene_set_expression_plots'
        unless params[:subsample].nil?
          params_key += "_#{params[:subsample]}"
        end
        if params[:gene_set]
          params_key += "_#{params[:gene_set].split.join('-')}"
        else
          gene_list = params[:search][:genes]
          gene_key = construct_gene_list_hash(gene_list)
          params_key += "_#{gene_key}"
        end
        params_key += "_#{params[:plot_type]}"
        unless params[:kernel_type].nil?
          params_key += "_#{params[:kernel_type]}"
        end
        unless params[:band_type].nil?
          params_key += "_#{params[:band_type]}"
        end
        render_gene_set_expression_plots_url(study_name: params[:study_name]) + params_key
      when 'expression_query'
        params_key += "_#{params[:row_centered]}"
        gene_list = params[:search][:genes]
        gene_key = construct_gene_list_hash(gene_list)
        params_key += "_#{gene_key}"
        expression_query_url(study_name: params[:study_name]) + params_key
      when 'annotation_query'
        annotation_query_url(study_name: params[:study_name]) + params_key
      when 'precomputed_results'
        precomputed_results_url(study_name: params[:study_name], precomputed: params[:precomputed].split.join('-'))
    end
  end
end
