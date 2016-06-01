class ClusterPoint
  include Mongoid::Document

  belongs_to :single_cell
  belongs_to :cluster
  belongs_to :study_file

  field :x, type: Float
  field :y, type: Float

  index({ single_cell_id: 1 }, { unique: false })
  index({ cluster_id: 1 }, { unique: false })

end
