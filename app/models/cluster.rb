class Cluster
  include Mongoid::Document

  field :name, type: String
  field :parent_cluster, type: String
  field :cluster_type, type: String

  belongs_to :study
  has_many :cluster_points
  has_many :single_cells

  index({ name: 1 }, { unique: false })
  index({ study_id: 1 }, { unique: false })

end
