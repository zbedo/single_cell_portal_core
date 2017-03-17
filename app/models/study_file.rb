class StudyFile
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Paperclip
  include Rails.application.routes.url_helpers

  # constants, used for statuses and file types
  STUDY_FILE_TYPES = ['Cluster', 'Expression Matrix', 'Gene List', 'Metadata', 'Fastq', 'Documentation', 'Other']
  PARSEABLE_TYPES = ['Cluster', 'Expression Matrix', 'Gene List', 'Metadata']
  UPLOAD_STATUSES = %w(new uploading uploaded)
  PARSE_STATUSES = %w(unparsed parsing parsed)

  # associations
  belongs_to :study, index: true
  has_many :cluster_groups, dependent: :destroy
  has_many :expression_scores, dependent: :destroy
  has_many :precomputed_scores, dependent: :destroy
  has_many :study_metadatas, dependent: :destroy

  # field definitions
  field :name, type: String
  field :path, type: String
  field :description, type: String
  field :file_type, type: String
  field :cluster_type, type: String
  field :status, type: String
  field :parse_status, type: String, default: 'unparsed'
  field :data_dir, type: String
  field :human_fastq_url, type: String
  field :human_data, type: Boolean, default: false
  field :x_axis_label, type: String, default: ''
  field :y_axis_label, type: String, default: ''
  field :z_axis_label, type: String, default: ''
  field :x_axis_min, type: Float
  field :x_axis_max, type: Float
  field :y_axis_min, type: Float
  field :y_axis_max, type: Float
  field :z_axis_min, type: Float
  field :z_axis_max, type: Float


  # callbacks
  before_create   :set_file_name_and_data_dir

  has_mongoid_attached_file :upload,
                            :path => ":rails_root/data/:data_dir/:filename",
                            :url => ''

  # turning off validation to allow any kind of data file to be uploaded
  do_not_validate_attachment_file_type :upload

  validates_uniqueness_of :upload_file_name, scope: :study_id, unless: Proc.new {|f| f.human_data?}

  Paperclip.interpolates :data_dir do |attachment, style|
    attachment.instance.data_dir
  end

  # return public url if study is public, otherwise redirect to create templink download url
  def download_path
    if self.upload_file_name.nil?
      self.human_fastq_url
    else
      if self.study.public?
        download_file_path(self.study.url_safe_name, self.upload_file_name)
      else
        download_private_file_path(self.study.url_safe_name, self.upload_file_name)
      end
    end
  end

  # JSON response for jQuery uploader
  def to_jq_upload(error=nil)
    {
        '_id' => self._id,
        'name' => read_attribute(:upload_file_name),
        'size' => read_attribute(:upload_file_size),
        'url' => download_path,
        'delete_url' => delete_study_file_study_path(self.study._id, self._id),
        'delete_type' => "DELETE"
    }
  end

  def parseable?
    PARSEABLE_TYPES.include?(self.file_type)
  end

  def parsed?
    self.parse_status == 'parsed'
  end

  # file type as a css class
  def file_type_class
    self.file_type.downcase.split.join('-') + '-file'
  end

  # return path to a file's 'public data' path (which will be a symlink to data dir)
  def public_data_path
    File.join(self.study.data_public_path, self.upload_file_name)
  end

  # single-use method to set data_dir for existing study_files
  def self.set_data_dir
    self.all.each do |study_file|
      if study_file.data_dir.nil?
        study_file.update(data_dir: study_file.study.data_dir)
        puts "Updated #{study_file.upload_file_name} with data_dir #{study_file.data_dir}"
      end
    end
    true
  end

  private

  # set filename and construct url safe name from study
  def set_file_name_and_data_dir
    if self.upload_file_name.nil?
      self.status = 'uploaded'
      if self.name.nil?
        self.name = ''
      end
    elsif (self.name.nil? || self.name.blank?) || (!self.new_record? && self.upload_file_name != self.name)
      self.name = self.upload_file_name
    end
    self.data_dir = self.study.data_dir
  end

  # set ranges for cluster_groups if necessary
  def set_cluster_group_ranges
    if self.file_type == 'Cluster' && self.cluster_groups.any?
      cluster = self.cluster_groups.first
      # check if range values are present and set accordingly
      if !self.x_axis_min.nil? && !self.x_axis_max.nil? && !self.y_axis_min.nil? && !self.y_axis_max.nil?
        domain_ranges = {
            x: [self.x_axis_min, self.x_axis_max],
            y: [self.y_axis_min, self.y_axis_max]
        }
        if !self.z_axis_min.nil? && !self.z_axis_max.nil?
          domain_ranges[:z] = [self.z_axis_min, self.z_axis_max]
        end
        cluster.update(domain_ranges: domain_ranges)
      else
        # either user has not supplied ranges or is deleting them, so clear entry for cluster_group
        cluster.update(domain_ranges: nil)
      end
    end
  end
end
