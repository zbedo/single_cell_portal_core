class ExternalResource
  include Mongoid::Document
  include Mongoid::Timestamps

  field :url, type: String
  field :title, type: String
  field :description, type: String
  field :publication_url, type: Mongoid::Boolean, default: false

  belongs_to :resource_links, polymorphic: true

  validates_presence_of :url, :title
  validates_uniqueness_of :title, scope: [:resource_links_id, :resource_links_type]
end
