class StudyMetadatum

  ###
  #
  # StudyMetadatum: class holding key/value pairs of cell-level annotations.  Not to be confused with HCA study-level metadata.
  #
  ###

  include Mongoid::Document

  belongs_to :study
  belongs_to :study_file

  field :name, type: String
  field :annotation_type, type: String
  field :cell_annotations, type: Hash
  field :values, type: Array

  index({ name: 1, annotation_type: 1, study_id: 1 }, { unique: false })
  index({ study_id: 1 }, { unique: false })
  index({ study_id: 1, study_file_id: 1 }, { unique: false })

  validates_uniqueness_of :name, scope: [:study_id, :annotation_type]
  validates_presence_of :name, :annotation_type, :cell_annotations


  MAX_ENTRIES = 10000000
  SUBSAMPLE_THRESHOLD = 1000
end
