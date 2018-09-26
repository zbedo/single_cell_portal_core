class Taxon
  include Mongoid::Document
  include ValidationTools
  include Swagger::Blocks

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

  swagger_schema :Taxon do
    key :required, [:common_name, :scientific_name, :taxon_identifier]
    key :name, 'Taxon'
    property :id do
      key :type, :string
    end
    property :common_name do
      key :type, :string
      key :description, 'Common name of this taxon/specie'
    end
    property :scientific_name do
      key :type, :string
      key :description, 'Scientific name of this taxon/specie'
    end
    property :taxon_identifier do
      key :type, :integer
      key :description, 'NCBI Taxon ID'
    end
    property :aliases do
      key :type, :string
      key :description, 'Comma-delimited list of aliases for this taxon/specie'
    end
    property :notes do
      key :type, :string
      key :description, 'Notes about this entry'
    end
    property :genome_assemblies do
      key :type, :array
      key :description, 'Genome Assemblies for this taxon/specie'
      items type: :object do
        key :title, 'GenomeAssembly'
        key :required, [:name, :release_date]
        property :name do
          key :type, :string
          key :description, 'Name of genome assembly'
        end
        property :release_date do
          key :type, :string
          key :format, :date
          key :description, 'Public release date of genome assembly'
        end
        property :alias do
          key :type, :string
          key :description, 'Alias for this genome assembly'
        end
        property :genome_annotations do
          key :type, :array
          key :description, 'Genome Annotations for this assembly'
          items type: :object do
            key :title, 'GenomeAnnotation'
            key :required, [:name, :link, :index_link, :release_date]
            property :name do
              key :type, :string
              key :description, 'Name of genome annotation'
            end
            property :link do
              key :type, :string
              key :description, 'URL or relative GCS path to annotation file'
            end
            property :index_link do
              key :type, :string
              key :description, 'URL or relative GCS path to annotation index file'
            end
            property :release_date do
              key :type, :string
              key :format, :date
              key :description, 'Public release date of genome annotation'
            end
          end
        end
      end
    end
    property :sync_status do
      key :type, :boolean
      key :description, 'Boolean indication whether this DirectoryListing has been synced (and made available for download)'
    end
    property :created_at do
      key :type, :string
      key :format, :date_time
      key :description, 'Creation timestamp'
    end
    property :updated_at do
      key :type, :string
      key :format, :date_time
      key :description, 'Last update timestamp'
    end
  end

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
