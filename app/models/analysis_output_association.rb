class AnalysisOutputAssociation
  include Mongoid::Document

  # class that represents a 'association' that must set on an output file from a workflow
  # assumes that all outputs are treated as study_files
  #
  # can be used to set an attribute directly on a study_file, such as its file_type, etc.
  # can also be used to set an association on a study_file based off of some other output

  belongs_to :analysis_parameter
  field :attribute_name, type: String # name of an attribute to set directly, e.g. file_type
  field :attribute_value, type: String # value of an attribute to set directly, e.g. 'Expression Matrix'
  field :association_source, type: String # name of other output parameter to source value from
  field :association_method, type: String # name of method to source value from for association from :output_parameter

  STUDY_FILE_ATTRIBUTES = {
      'file_type' => StudyFile::STUDY_FILE_TYPES,
  }
  ASSOCIATION_METHODS = %w(taxon_id genome_assembly_id study_file_bundle_id)
end
