class PrecomputedScore
	include Mongoid::Document

	belongs_to :study
	belongs_to :study_file

	field :name, type: String
	field :clusters, type: Array
	field :gene_scores, type: Array

	def gene_list
		self.gene_scores.map(&:keys).flatten
	end
end