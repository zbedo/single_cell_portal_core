class StudyFileBundle
  include Mongoid::Document
  include Mongoid::Timestamps
  field :bundle_type, type: String
  field :original_file_list, type: Array, default: []

  belongs_to :study
  has_many :study_files

  # allowed bundle types
  BUNDLE_TYPES = ['MM Coordinate Matrix', 'BAM', 'Cluster']
  # required keys for file list
  FILE_LIST_KEYS = %w(name file_type)
  # child file type requirements by bundle type
  BUNDLE_REQUIREMENTS = {
      'MM Coordinate Matrix' => ['10X Genes File', '10X Barcodes File'],
      'BAM' => ['BAM Index'],
      'Cluster' => ['Coordinate Labels']
  }
  PARSEABLE_BUNDLE_REQUIREMENTS = BUNDLE_REQUIREMENTS.dup.keep_if {|k,v| k != 'BAM'}

  before_validation :set_bundle_type, on: :create
  validates_presence_of :bundle_type, :original_file_list
  validates_inclusion_of :bundle_type, in: BUNDLE_TYPES
  validate :validate_file_list_contents, on: :create
  validate :validate_bundle_by_type
  after_validation :initialize_study_file_associations, on: :create

  before_destroy :remove_bundle_associations

  # parent file of this bundle (same as bundle_type)
  def parent
    self.study_files.find_by(file_type: self.bundle_type)
  end

  # child/dependent files in this bundle
  def bundled_files
    self.study_files.where(:id.ne => self.parent.id)
  end

  # return the target of this bundle (StudyFile for MM matrices & BAMs, ClusterGroup for Clusters)
  def bundle_target
    if self.bundle_type == 'Cluster'
      ClusterGroup.find_by(study_file_id: self.parent.id)
    else
      self.parent
    end
  end

  def file_types
    self.study_files.map(&:file_type)
  end

  def original_file_types
    self.original_file_list.map {|file| file['file_type']}
  end

  private

  # from the original_file_types list, find the file that matches the bundle type
  def match_bundle_type
    self.original_file_types & BUNDLE_TYPES
  end

  def set_bundle_type
    unless self.bundle_type.present?
      if match_bundle_type.size == 1
        self.bundle_type = match_bundle_type.first
      end
    end
  end

  # make sure the original_file_list is in the correct format for extracting file information
  def validate_file_list_contents
    keys = self.original_file_list.map(&:keys).flatten.uniq.sort
    unless (keys & FILE_LIST_KEYS) == keys
      errors.add(:original_file_list, " is formatted incorrectly.  This must be an array of Hashes with the keys #{FILE_LIST_KEYS.join(', ')}." )
    end
    self.original_file_list.each do |file|
      unless StudyFile::STUDY_FILE_TYPES.include?(file['file_type'])
        errors.add(:original_file_list, " contains a file of an invalid type: #{file['file_type']}")
      end
    end
    unless match_bundle_type.any?
      errors.add(:original_file_list, " does not contain a file of the specified bundle type: #{self.bundle_type}")
    end
    if match_bundle_type.size > 1
      errors.add(:original_file_types, " contains files of incompatible types: #{match_bundle_type.join(', ')}")
    end
  end

  # validate that the supplied files are of the correct type for the given bundle
  def validate_bundle_by_type
    parent_file = self.original_file_list.detect {|file| file['file_type'] == self.bundle_type}
    child_files = self.original_file_list.select {|file| file != parent_file}
    child_file_types = child_files.map {|file| file['file_type']}
    if child_file_types.size < BUNDLE_REQUIREMENTS[self.bundle_type].size || ( (child_file_types.size == BUNDLE_REQUIREMENTS[self.bundle_type].size) &&
        (child_file_types & BUNDLE_REQUIREMENTS[self.bundle_type] != child_file_types))
      errors.add(:original_file_list, " is missing a file of the required type: #{(StudyFileBundle::BUNDLE_REQUIREMENTS[self.bundle_type] - child_file_types).join(', ')}")
    end
    if child_file_types.size > BUNDLE_REQUIREMENTS[self.bundle_type].size
      errors.add(:original_file_list, " has a file of an invalid file type: #{(child_file_types - StudyFileBundle::BUNDLE_REQUIREMENTS[self.bundle_type]).join(', ')}")
    end
  end

  # set study_file associations after successful validation
  def initialize_study_file_associations
    self.original_file_list.each do |file_entry|
      filename = file_entry['name']
      file_type = file_entry['file_type']
      species_name = file_entry['species']
      assembly_name = file_entry['assembly']
      study_file = StudyFile.find_by(file_type: file_type, upload_file_name: filename, study_id: self.study_id)
      if study_file.present?
        study_file.update(study_file_bundle_id: self.id)
      else
        study_file = self.study.study_files.build(file_type: file_type, upload_file_name: filename, study_file_bundle_id: self.id)
        if StudyFile::TAXON_REQUIRED_TYPES.include?(file_type) && Taxon.present?
          study_file.taxon_id = Taxon.first.id # temporarily set arbitrary taxon association
          if species_name.present?
            taxon = Taxon.where(common_name: /#{species_name}/i).first
            taxon.present? ? study_file.taxon_id : nil # set requested taxon if we find it
          end
        end
        if StudyFile::ASSEMBLY_REQUIRED_TYPES.include?(file_type) && GenomeAssembly.present?
          study_file.genome_assembly_id = GenomeAssembly.first.id # temporarily set arbitrary assembly association
          if species_name.present?
            assembly = GenomeAssembly.where(name: /#{assembly_name}/i).first
            assembly.present? ? study_file.genome_assembly_id : nil # set requested assembly if we find it
          end
        end
        study_file.save!
      end
    end
  end

  # unset all associations on delete
  def remove_bundle_associations
    self.study_files.update_all(study_file_bundle_id: nil)
  end
end
