class ExpressionScore
  include Mongoid::Document

  belongs_to :study

  field :gene, type: String
  field :searchable_gene, type: String
  field :scores, type: Hash

end
