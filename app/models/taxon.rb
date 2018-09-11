class Taxon
  include Mongoid::Document
  include ValidationTools

  has_many :study_files
  belongs_to :user

  field :common_name, type: String
  field :scientific_name, type: String
  field :taxon_id, type: Integer
  field :genome_assembly, type: String
  field :genome_assembly_alias, type: String
  field :genome_annotation, type: String
  field :genome_annotation_link, type: String
  field :aliases, type: Array, default: []
  field :notes, type: String

  validates_presence_of :common_name, :scientific_name, :taxon_id, :genome_assembly,
                        :genome_annotation, :genome_annotation_link, :notes
  validates_format_of :common_name, :scientific_name, with: ALPHANUMERIC_SPACE_DASH,
                      message: ALPHANUMERIC_SPACE_DASH_ERROR

  validates_uniqueness_of :genome_annotation, scope: :taxon_id

  validate :check_genome_annotation_link

  before_destroy :remove_study_file_associations


  def self.sorted
    self.all.order_by(common_name: :asc, genome_annotation: :asc)
  end

  def display_name
    "#{self.common_name} (#{self.genome_assembly}, #{self.genome_annotation})"
  end

  # generate a URL that can be accessed publicly for this genome annotation
  def public_genome_annotation_link
    if self.genome_annotation_link.starts_with?('http')
      self.genome_annotation_link
    else
      # assume the link is a relative path to a file in a GCS bucket, then use the Read-Only client to generate a signed URL
      config = AdminConfiguration.find_by(config_type: 'Reference Data Workspace')
      if config.present?
        begin
          reference_project, reference_workspace = config.value.split('/')
          Study.read_only_firecloud_client.execute_gcloud_method(:generate_signed_url, reference_project,
                                                                 reference_workspace, self.genome_annotation_link,
                                                                 expires: 1.hour)
        rescue => e
          Rails.logger.error "Cannot generate public genome annotation link for #{self.genome_annotation_link}: #{e.message}"
          nil
        end
      else
        nil
      end
    end
  end

  private

  def remove_study_file_associations
    self.study_files.update_all(taxon_id: nil)
  end

  # validate that the supplied genome annotation link is valid
  def check_genome_annotation_link
    if self.genome_annotation_link.starts_with?('http')
      begin
        response = RestClient.get genome_annotation_link
        unless response.code == 200
          errors.add(:genome_annotation_link, "was not found at the specified link: #{genome_annotation_link}.  The response code was #{response.code} rather than 200.")
        end
      rescue => e
        errors.add(:genome_annotation_link, "was not found due to an error: #{e.message}.  Please check the link and try again.")
      end
    else
      # assume the link is a relative path to a file in a GCS bucket
      config = AdminConfiguration.find_by(config_type: 'Reference Data Workspace')
      if config.present?
        begin
          reference_project, reference_workspace = config.value.split('/')
          genome_file = Study.firecloud_client.execute_gcloud_method(:get_workspace_file, reference_project, reference_workspace,
                                                                     self.genome_annotation_link)
          if !genome_file.present?
            errors.add(:genome_annotation_link, "was not found in the reference workspace of #{config.value}.  Please check the link and try again.")
          end
        rescue => e
          errors.add(:genome_annotation_link, "was not found due to an error: #{e.message}.  Please check the link and try again.")
        end
      else
        errors.add(:genome_annotation_link, '- you have not specified a Reference Data Workspace.  Please add this via the Admin Config panel before registering a taxon.')
      end
    end
  end
end
