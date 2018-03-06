class BrandingGroup
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Paperclip

  field :name, type: String
  field :name_as_id, type: String
  field :tag_line, type: String
  field :background_color, type: String
  field :font_family, type: String, default: 'Helvetica Neue'
  field :font_color, type: String, default: '#333333'

  has_many :studies
  belongs_to :user

  has_mongoid_attached_file :splash_image,
                            :path => ":rails_root/public/single_cell/branding_groups/:id/:filename",
                            :url => "/single_cell/branding_groups/:id/:filename"

  validates_attachment :splash_image,
                       content_type: { content_type: ['image/jpeg', 'image/png'] },
                       size: { in: 0..10.megabytes }

  validates_presence_of :name, :name_as_id, :background_color, :font_family
  validates_uniqueness_of :name

  before_validation :set_name_as_id

  private

  def set_name_as_id
    self.name_as_id = self.name.downcase.gsub(/[^a-zA-Z0-9]+/, '-').chomp('-')
  end
end
