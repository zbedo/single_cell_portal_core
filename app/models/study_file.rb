class StudyFile
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Paperclip
  include Rails.application.routes.url_helpers

  STUDY_FILE_TYPES = ['Cluster Coordinates', 'Cluster Assignments', 'Expression Matrix', 'Marker Gene List', 'Raw Source', 'Documentation', 'Other']
  UPLOAD_STATUSES = %w(new uploading uploaded)

  belongs_to :study, index: true

  field :name, type: String
  field :path, type: String
  field :description, type: String
  field :file_type, type: String
  field :url_safe_name, type: String
  field :status, type: String

  before_create   :make_data_dir
  before_create   :set_file_name_and_url_safe_name
  after_save      :check_public?
  before_destroy  :remove_public_symlink

  has_mongoid_attached_file :upload,
                            :path => ":rails_root/data/:url_safe_name/:filename",
                            :url => "/single_cell_demo/data/:url_safe_name/:filename"

  # turning off validation to allow any kind of data file to be uploaded
  do_not_validate_attachment_file_type :upload

  Paperclip.interpolates :url_safe_name do |attachment, style|
    attachment.instance.url_safe_name
  end

  def download_path
    if self.study.public?
      self.upload.url
    else
      download_private_file_path(self.study.url_safe_name, self.upload_file_name)
    end
  end

  def file_size
    File.size?(self.path)
  end

  def to_jq_upload
    {
        '_id' => self._id,
        'name' => read_attribute(:upload_file_name),
        'size' => read_attribute(:upload_file_size),
        'url' => download_path,
        'delete_url' => delete_study_file_study_path(self.study._id, self._id),
        'delete_type' => "DELETE"
    }
  end

  private

  def make_data_dir
    data_dir = Rails.root.join('data', self.study.url_safe_name)
    unless Dir.exist?(data_dir)
      Dir.mkdir(data_dir)
    end
  end

  def set_file_name_and_url_safe_name
    self.name = self.upload_file_name
    self.url_safe_name = self.study.url_safe_name
  end

  # add symlink if study is public
  def check_public?
    if self.study.public? && self.status == 'uploaded'
      FileUtils.ln_sf(self.upload.path, File.join(self.study.data_public_path, self.upload_file_name))
    end
  end

  # clean up any symlinks before deleting a study file
  def remove_public_symlink
    if self.study.public?
      FileUtils.rm_f(File.join(self.study.data_public_path, self.upload_file_name))
    end
  end
end
