class DataArray
	include Mongoid::Document

	DATA_ARRAY_TYPES = %w(coordinates annotations cells)

	field :name, type: String
	field :cluster_name, type: String
	field :array_type, type: String
	field :array_index, type: Integer
	field :values, type: Array
	field :subsample_threshold, type: Integer
	field :subsample_annotation, type: String
	belongs_to :study
	belongs_to :study_file
	belongs_to :cluster_group

	index({ name: 1, study_id: 1, cluster_group_id: 1, cluster_name: 1,
								array_type: 1, array_index: 1, subsample_threshold: 1, subsample_annotation: 1 },
				{ unique: true, name: 'unique_data_arrays_index' })
	index({ study_id: 1 }, { unique: false })
	index({ study_id: 1, study_file_id: 1}, { unique: false })


	# maximum number of entries for values array (to avoid MongoDB max document size problems)
	MAX_ENTRIES = 100000

end