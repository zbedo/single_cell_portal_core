class FirestoreCluster
  include ActiveModel::AttributeAssignment
  include FirestoreDocuments
  include FirestoreSubDocuments

  attr_accessor :name, :study_accession, :cluster_type, :points, :cell_annotations, :domain_ranges, :file_id, :document

  ##
  # Firestore collection setters
  ##

  def self.collection_name
    :clusters
  end

  def self.sub_collection_name
    :data
  end

  ##
  # Instance methods
  ##

  # method to return a single data array of values for a given data array name, annotation name, and annotation value
  # gathers all matching data arrays and orders by index, then concatenates into single array
  # can also load subsample arrays by supplying optional subsample_threshold
  def concatenate_data_arrays(array_name, array_type, subsample_threshold=nil, subsample_annotation=nil)
    docs = self.sub_documents.where(:name, :==, array_name).
        where(:array_type, :==, array_type)
    if subsample_threshold.present? # only append extra queries if a threshold is present
      docs = docs.where(:subsample_threshold, :==, subsample_threshold).
          where(:subsample_annotation, :==, subsample_annotation)
    end
    docs.get.sort_by {|d| d[:array_index]}.map {|d| d.data[:values]}.flatten
  end

  def is_3d?
    self.cluster_type == '3d'
  end

  # check if user has defined a range for this cluster_group (provided in study file)
  def has_range?
    !self.domain_ranges.nil?
  end

  # TODO: reimplement this to either write coordinate label data to Firestore, or preserve MongoDB query
  def has_coordinate_labels?
    false
  end

  # return a formatted array for use in a select dropdown that corresponds to a specific cell_annotation
  def formatted_cell_annotation(annotation, prepend_name=false)
    ["#{annotation[:name]}", "#{prepend_name ? "#{self.name}--" : nil}#{annotation[:name]}--#{annotation[:type]}--cluster"]
  end

  # generate a formatted select box options array that corresponds to all this cluster_group's cell_annotations
  # can be scoped to cell_annotations of a specific type (group, numeric)
  def cell_annotation_select_option(annotation_type=nil, prepend_name=false)
    annotations = annotation_type.nil? ? self.cell_annotations : self.cell_annotations.select {|annot| annot[:type] == annotation_type}
    annotations.map {|annot| self.formatted_cell_annotation(annot, prepend_name)}
  end

  # list of cell annotation header values by type (group or numeric)
  def cell_annotation_names_by_type(type)
    self.cell_annotations.select {|annotation| annotation['type'] == type}.map {|annotation| annotation['name']}
  end

end