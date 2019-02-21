class GenomeAssembly
  include Mongoid::Document

  belongs_to :taxon
  has_many :study_files
  has_many :directory_listings
  has_many :genome_annotations, dependent: :destroy
  accepts_nested_attributes_for :genome_annotations, allow_destroy: true

  field :name, type: String
  field :alias, type: String
  field :release_date, type: Date
  field :accession, type: String

  ASSOCIATED_MODEL_METHOD = %w(name accession)
  ASSOCIATED_MODEL_DISPLAY_METHOD = %w(name accession)
  OUTPUT_ASSOCIATION_ATTRIBUTE = %w(study_file_id taxon_id)
  ASSOCIATION_FILTER_ATTRIBUTE = %w(name accession)

  validates_presence_of :name, :release_date, :accession
  validates_uniqueness_of :accession, scope: :taxon_id

  def current_annotation
    if self.genome_annotations.any?
      self.genome_annotations.order(release_date: :desc).first
    else
      nil
    end
  end
end
