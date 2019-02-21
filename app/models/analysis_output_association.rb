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
  field :association_data_type, type: String # type of source parameter (e.g. inputs/outputs)

  STUDY_FILE_ATTRIBUTES = %w(description options.visualization_name options.analysis_name human_data)
  ASSOCIATION_METHODS = %w(taxon_id genome_assembly_id study_file_bundle_id)

  # set attributes or associations on file in memory (must be saved explicitly by user)
  def process_output_file(output_study_file, source_configuration, study)
    if self.attribute_name.present? && self.attribute_value.present?
      output_study_file.attributes[self.attribute_name] = attribute_value
    end
    if self.association_source.present? && self.association_method.present?
      parameter_value = source_configuration[self.association_data_type][self.association_source]
      filename = parameter_value.gsub(/\"/,'').gsub(/gs\:\/\/#{study.bucket_id}\//, '')
      existing_file = study.study_files.any_of({upload_file_name: filename},{name: filename},{remote_location: filename}).first
      output_study_file.attributes[self.association_method] = existing_file.send(self.association_method)
    end
    output_study_file
  end
end
