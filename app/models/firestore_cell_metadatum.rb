class FirestoreCellMetadatum
  include ActiveModel::AttributeAssignment
  include FirestoreDocuments
  include FirestoreSubDocuments

  attr_accessor :name, :study_accession, :annotation_type, :unique_values, :file_id, :document

  def self.collection_name
    :cell_metadata
  end

  def self.sub_collection_name
    :data
  end

  def self.by_study_and_name_and_type(accession, name, annotation_type)
    doc_ref = self.query_by(study_accession: accession, name: name, annotation_type: annotation_type)
    doc_ref.any? ? self.new(doc_ref.first) : nil
  end

  def cell_annotations
    self.sub_documents_as_hash(:cell_names, :values)
  end

  # generate a select box option for use in dropdowns that corresponds to this cell_metadatum
  def annotation_select_option
    [self.name, self.annotation_select_value]
  end

  def annotation_select_value
    "#{self.name}--#{self.annotation_type}--study"
  end

end
