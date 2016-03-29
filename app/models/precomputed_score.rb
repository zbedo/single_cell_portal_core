class PrecomputedScore
	include Mongoid::Document

	belongs_to :study

	field :name, type: String
	field :clusters, type: Array
	field :gene_scores, type: Array
end