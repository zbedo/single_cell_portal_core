class GenomeAnnotation
  include Mongoid::Document

  belongs_to :genome_assembly
  has_many :study_files

  field :name, type: String
  field :link, type: String
  field :release_date, type: Date

  validates_presence_of :name, :link, :release_date
  validates_uniqueness_of :name, scope: :genome_assembly_id

  validate :check_genome_annotation_link

  before_destroy :remove_study_file_associations

  def display_name
    "#{self.name} (#{self.release_date.strftime("%D")})"
  end

  # generate a URL that can be accessed publicly for this genome annotation
  def public_annotation_link
    if self.link.starts_with?('http')
      self.link
    else
      # assume the link is a relative path to a file in a GCS bucket, then use the Read-Only client to generate a signed URL
      config = AdminConfiguration.find_by(config_type: 'Reference Data Workspace')
      if config.present?
        begin
          reference_project, reference_workspace = config.value.split('/')
          Study.read_only_firecloud_client.execute_gcloud_method(:generate_api_url, reference_project,
                                                                 reference_workspace, self.link)
        rescue => e
          Rails.logger.error "Cannot generate public genome annotation link for #{self.link}: #{e.message}"
          ''
        end
      else
        ''
      end
    end
  end


  private

  def remove_study_file_associations
    self.study_files.update_all(taxon_id: nil)
  end

  # validate that the supplied genome annotation link is valid
  def check_genome_annotation_link
    if self.link.starts_with?('http')
      begin
        response = RestClient.get link
        unless response.code == 200
          errors.add(:link, "was not found at the specified link: #{link}.  The response code was #{response.code} rather than 200.")
        end
      rescue => e
        errors.add(:link, "was not found due to an error: #{e.message}.  Please check the link and try again.")
      end
    else
      # assume the link is a relative path to a file in a GCS bucket
      config = AdminConfiguration.find_by(config_type: 'Reference Data Workspace')
      if config.present?
        begin
          reference_project, reference_workspace = config.value.split('/')
          genome_file = Study.firecloud_client.execute_gcloud_method(:get_workspace_file, reference_project, reference_workspace,
                                                                     self.link)
          if !genome_file.present?
            errors.add(:link, "was not found in the reference workspace of #{config.value}.  Please check the link and try again.")
          end
        rescue => e
          errors.add(:link, "was not found due to an error: #{e.message}.  Please check the link and try again.")
        end
      else
        errors.add(:link, '- you have not specified a Reference Data Workspace.  Please add this via the Admin Config panel before registering a taxon.')
      end
    end
  end
end
