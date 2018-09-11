class GenomeAssembly
  include Mongoid::Document

  belongs_to :taxon
  has_many :genome_annotations, dependent: :destroy
  accepts_nested_attributes_for :genome_annotations, allow_destroy: true

  field :name, type: String
  field :alias, type: String
  field :release_date, type: Date

  validates_presence_of :name, :release_date
  validates_uniqueness_of :name, scope: :taxon_id
end
