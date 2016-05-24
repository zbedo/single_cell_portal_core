class StudyFile
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Paperclip
  include Rails.application.routes.url_helpers

  STUDY_FILE_TYPES = ['Cluster Coordinates', 'Cluster Assignments', 'Expression Matrix', 'Marker Gene List', 'Raw Source', 'Documentation', 'Other']

  belongs_to :study

  field :name, type: String
  field :path, type: String
  field :description, type: String
  field :file_type, type: String

  before_create :make_data_dir
  before_create :set_file_name

  has_mongoid_attached_file :data,
                            :path => ':rails_root/data/:url_safe_name/:data_file_name',
                            :url => '/single_cell_demo/data/:url_safe_name/:data_file_name'

  #
  do_not_validate_attachment_file_type :data

  Paperclip.interpolates :url_safe_name do |attachment, style|
    attachment.instance.study.url_safe_name
  end

  Paperclip.interpolates :data_file_name do |attachment, style|
    attachment.instance.data_file_name
  end

  def download_path
    if self.study.public?
      self.data.url
    else
      download_private_file_path(self.study.url_safe_name, self.data_file_name)
    end
  end

  def file_size
    File.size?(self.path)
  end

  private

  def make_data_dir
    data_dir = Rails.root.join('data', self.study.url_safe_name)
    unless Dir.exist?(data_dir)
      Dir.mkdir(data_dir)
    end
  end

  def set_file_name
    self.name = self.data_file_name
  end
end
