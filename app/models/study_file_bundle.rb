class StudyFileBundle
  include Mongoid::Document
  include Mongoid::Timestamps
  field :bundle_type, type: String
  field :original_file_list, type: Array, default: []

  belongs_to :study
  has_many :study_files

  BUNDLE_TYPES = ['MM Coordinate Matrix', 'BAM', 'Cluster']
  FILE_LIST_KEYS = %w(name file_type)

  before_validation :set_bundle_type, on: :create
  validates_presence_of :bundle_type, :original_file_list
  validates_inclusion_of :bundle_type, in: BUNDLE_TYPES
  validate :validate_file_list_contents, on: :create

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
    keys = self.original_file_list.map(&:keys).uniq.sort
    unless keys == FILE_LIST_KEYS
      errors.add(:original_file_list, ' is formatted incorrectly.  This must be an array of Hashes with the keys ' + FILE_LIST_KEYS.join(', ') + '.' )
    end
    self.original_file_list.each do |file|
      unless StudyFile::STUDY_FILE_TYPES.include?(file['file_type'])
        errors.add(:original_file_list, ' contains a file of an invalid type: ' + file['file_type'])
      end
    end
    unless match_bundle_type.any?
      errors.add(:original_file_list, ' does not contain a file of the specified bundle type: ' + self.bundle_type)
    end
    if match_bundle_type.size > 1
      errors.add(:original_file_types, ' contains files of incompatible types: ' + match_bundle_type.join(', '))
    end
  end

  def remove_bundle_associations
    self.study_files.update_all(study_file_bundle_id: nil)
  end
end
