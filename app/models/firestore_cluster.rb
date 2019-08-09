class FirestoreCluster
  include ActiveModel::AttributeAssignment

  ACCEPTED_DOCUMENT_FORMATS = [Google::Cloud::Firestore::DocumentSnapshot, Google::Cloud::Firestore::DocumentReference]

  attr_accessor :name, :study_accession, :cluster_type, :points, :cell_annotations, :domain_ranges, :file_id, :document

  def initialize(document_snapshot)
    unless ACCEPTED_DOCUMENT_FORMATS.include? document_snapshot.class
      raise ArgumentError, "invalid Firestore document instance: #{document_snapshot.class.name}, must be in #{ACCEPTED_DOCUMENT_FORMATS}"
    end

    if document_snapshot.is_a?(Google::Cloud::Firestore::DocumentSnapshot)
      self.document = document_snapshot
    elsif document_snapshot.is_a?(Google::Cloud::Firestore::DocumentReference)
      self.document = document_snapshot.get
    end

    self.attributes = document.data
  end

  def attributes
    {
        name: name,
        study_accession: study_accession,
        cluster_type: cluster_type,
        points: points,
        cell_annotations: cell_annotations,
        domain_ranges: domain_ranges,
        file_id: file_id
    }
  end

  ##
  # Firestore convenience methods
  ##

  def self.client
    ApplicationController.firestore_client
  end

  def self.collection_name
    :clusters
  end

  def self.sub_collection_name
    :data
  end

  def self.collection
    self.client.col(self.collection_name)
  end

  def reference
    self.document.reference
  end

  def document_id
    self.document.document_id
  end

  def sub_documents
    self.reference.col(FirestoreCluster.sub_collection_name)
  end

  ##
  # Query methods
  ##

  def self.by_study(accession)
    self.collection.where(:study_accession, :==, accession).get
  end

  def self.by_study_and_name(accession, name)
    self.collection.where(:study_accession, :==, accession).where(:name, :==, name).get.first
  end

  def self.count(query={})
    if query.empty?
      self.collection.get.count
    else
      collection_ref = self.collection
      query.each do |attr, val|
        collection_ref = collection_ref.where(attr.to_sym, :==, val)
      end
      collection_ref.get.count
    end
  end

  def self.exists?(query={})
    if query.empty?
      false
    else
      self.count(query) > 0
    end
  end

  ##
  # Instance methods
  ##

  # method to return a single data array of values for a given data array name, annotation name, and annotation value
  # gathers all matching data arrays and orders by index, then concatenates into single array
  # can also load subsample arrays by supplying optional subsample_threshold
  def concatenate_data_arrays(array_name, array_type, subsample_threshold=nil, subsample_annotation=nil)
    docs = self.sub_documents.where(:name, :==, array_name).
        where(:array_type, :==, array_type).
        where(:subsample_threshold, :==, subsample_threshold).
        where(:subsample_annotation, :==, subsample_annotation)
    docs.get.sort_by {|d| d[:array_index]}.map {|d| d.data[:values]}.flatten
  end

  def is_3d?
    self.cluster_type == '3d'
  end

  # check if user has defined a range for this cluster_group (provided in study file)
  def has_range?
    !self.domain_ranges.nil?
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

  def study_file
    StudyFile.find(self.file_id)
  end

end