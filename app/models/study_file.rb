class StudyFile
  include Mongoid::Document
  include Mongoid::Timestamps

  belongs_to :study

  field :name, type: String
  field :path, type: String
  field :description, type: String

  def download_path
    "/data/#{self.study.url_safe_name}/#{self.name}"
  end

  def file_size
    File.size?(self.path)
  end
end
