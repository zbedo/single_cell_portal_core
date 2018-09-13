class Taxon
  include Mongoid::Document
  include ValidationTools

  has_many :study_files
  has_many :directory_listings
  has_many :genome_assemblies, dependent: :destroy
  accepts_nested_attributes_for :genome_assemblies, allow_destroy: true
  belongs_to :user

  field :common_name, type: String
  field :scientific_name, type: String
  field :taxon_identifier, type: Integer
  field :aliases, type: String
  field :notes, type: String

  validates_presence_of :common_name, :scientific_name, :taxon_identifier, :notes
  validates_format_of :common_name, :scientific_name, with: ALPHANUMERIC_SPACE_DASH,
                      message: ALPHANUMERIC_SPACE_DASH_ERROR

  before_destroy :remove_study_file_associations

  RESTRICTED_NCBI_TAXON_IDS = [9606]

  def self.sorted
    self.all.order_by(common_name: :asc)
  end

  def display_name
    "#{self.common_name}"
  end

  private

  def remove_study_file_associations
    self.study_files.update_all(taxon_id: nil)
  end
end
