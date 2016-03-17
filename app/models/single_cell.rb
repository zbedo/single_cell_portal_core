class SingleCell
  include Mongoid::Document

  field :name, type: String

  has_many :cluster_points

  belongs_to :study
  belongs_to :cluster

  validates_uniqueness_of :name, scope: :study_id

end
