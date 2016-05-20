class StudyFile
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Paperclip

  STUDY_FILE_TYPES

  belongs_to :study

  field :name, type: String
  field :path, type: String
  field :description, type: String
  field :file_type, type: String

  has_mongoid_attached_file :data,
                            :path => '/data/:url_safe_name/:name',
                            :url => '/single_cell_demo/data/:url_safe_name/:name'

  Paperclip.interpolates :url_safe_name do |attachment, style|
    attachment.instance.study.url_safe_name
  end

  def download_path
    "/single_cell_demo/data/#{self.study.url_safe_name}/#{self.name}"
  end

  def file_size
    File.size?(self.path)
  end
end
