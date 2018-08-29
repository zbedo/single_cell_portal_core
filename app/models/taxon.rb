class Taxon
  include Mongoid::Document
  include ValidationTools

  has_many :study_files

  field :common_name, type: String
  field :scientific_name, type: String
  field :taxon_id, type: Integer
  field :genome_assembly, type: String
  field :genome_assembly_alias, type: String
  field :genome_annotation, type: String
  field :genome_annotation_link, type: String
  field :aliases, type: Array, default: []

  validates_presence_of :common_name, :scientific_name, :taxon_id, :genome_assembly,
                        :genome_annotation, :genome_annotation_link
  validates_format_of :common_name, :scientific_name, with: ALPHANUMERIC_SPACE_DASH,
                      message: ALPHANUMERIC_SPACE_DASH_ERROR

  validates_uniqueness_of :genome_annotation, scope: :taxon_id

  before_destroy :remove_study_file_associations


  def self.sorted
    self.all.order_by(common_name: :asc, genome_annotation: :asc)
  end

  def selection_name
    "#{self.common_name} (#{self.genome_annotation})"
  end

  private

  def remove_study_file_associations
    self.study_files.update_all(taxon_id: nil)
  end

end
