class ExpressionScore

  ###
  #
  # ExpressionScore: gene-based class that holds key/value pairs of cell names and gene expression scores
  #
  ###

  include Mongoid::Document

  belongs_to :study
  belongs_to :study_file

  field :gene, type: String
  field :searchable_gene, type: String
  field :scores, type: Hash

  index({ gene: 1, study_id: 1, study_file_id: 1 }, { unique: true, background: true})
  index({ searchable_gene: 1, study_id: 1 }, { unique: false, background: true })
  index({ study_id: 1 }, { unique: false, background: true })
  index({ study_id: 1, study_file_id: 1} , { unique: false, background: true })

  validates_uniqueness_of :gene, scope: [:study_id, :study_file_id]
  validates_presence_of :gene

  def mean(cells)
    sum = 0.0
    cells.each do |cell|
      sum += self.scores[cell].to_f
    end
    sum / cells.size
  end

  # calculate a mean value for a given gene based on merged expression scores
  def self.mean(scores, cells)
    values = cells.map {|c| scores[c].to_f}
    values.mean
  end

  # calculate a z-score for every entry (subtract the mean, divide by the standard deviation)
  def self.z_score(scores, cells)
    values = cells.map {|c| scores[c].to_f}
    mean = values.mean
    stddev = values.stdev
    values.map {|v| (v - mean) / stddev}
  end

  # calculate a robust z-score for every entry (subtract the median, divide by the absolute median deviation)
  def self.robust_z_score(scores, cells)
    values = cells.map {|c| scores[c].to_f}
    sorted_values = values.sort
    len = sorted_values.length
    median = (sorted_values[(len - 1) / 2] + sorted_values[len / 2]) / 2.0
    deviations = values.map {|v| median - v}
    abs_median_dev = deviations.reduce(:+) / values.size
    values.map {|v| (v - median) / abs_median_dev}
  end
end
