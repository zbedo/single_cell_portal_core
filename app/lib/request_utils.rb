class RequestUtils
  def self.get_selected_annotation(params, study, cluster)
    selector = params[:annotation].nil? ? params[:gene_set_annotation] : params[:annotation]
    annot_name, annot_type, annot_scope = selector.nil? ? study.default_annotation.split('--') : selector.split('--')

    # construct object based on name, type & scope
    case annot_scope
    when 'cluster'
      annotation_source = cluster.cell_annotations.find {|ca| ca[:name] == annot_name && ca[:type] == annot_type}
    when 'user'
      annotation_source = UserAnnotation.find(annot_name)
    else
      annotation_source = study.cell_metadata.by_name_and_type(annot_name, annot_type)
    end
    # rescue from an invalid annotation request by defaulting to the first cell metadatum present
    if annotation_source.nil?
      annotation_source = study.cell_metadata.first
    end
    populate_annotation_by_class(source: annotation_source, scope: annot_scope, type: annot_type)
  end

  # attempt to load an annotation based on instance class
  def self.populate_annotation_by_class(source:, scope:, type:)
    if source.is_a?(CellMetadatum)
      annotation = {name: source.name, type: source.annotation_type,
                    scope: 'study', values: source.values.present? ? source.values : [],
                    identifier: "#{source.name}--#{type}--#{scope}"}
    elsif source.is_a?(UserAnnotation)
      annotation = {name: source.name, type: type, scope: scope, values: source.values.present? ? source.values : [],
                    identifier: "#{source.name}--#{type}--#{scope}"}
    elsif source.is_a?(Hash)
      annotation = {name: source[:name], type: type, scope: scope, values: source[:values].present? ? source[:values] : [],
                    identifier: "#{source[:name]}--#{type}--#{scope}"}
    end
    annotation
  end

  def self.get_cluster_group(params, study)
    # determine which URL param to use for selection
    selector = params[:cluster].nil? ? params[:gene_set_cluster] : params[:cluster]
    if selector.nil? || selector.empty?
      study.default_cluster
    else
      study.cluster_groups.by_name(selector)
    end
  end

  # sanitizes a page param into an integer.  Will default to 1 if the value
  # is nil or otherwise can't be read
  def self.sanitize_page_param(page_param)
    page_num = 1
    parsed_num = page_param.to_i
    if (parsed_num > 0)
      page_num = parsed_num
    end
    page_num
  end

  # TODO: remove regex characters, except for ()
  def self.sanitize_search_param(parameter)
    if parameter.is_a?(Array)
      parameter.map(&:strip)
    else
      parameter.split(/[\s,]/).map(&:strip)
    end
  end
end
