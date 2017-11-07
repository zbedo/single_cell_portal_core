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

  # calculate a mean value for a given gene based on merged expression scores hash
  def self.mean(scores, cells)
    values = cells.map {|c| scores[c].to_f}
    values.mean
  end

  # calculate a median value for a given gene based on merged expression scores hash
  def self.median(scores, cells)
    values = cells.map {|c| scores[c].to_f}
    self.array_median(values)
  end

  # calculate median of an array
  def self.array_median(values)
    sorted_values = values.sort
    len = sorted_values.length
    (sorted_values[(len - 1) / 2] + sorted_values[len / 2]) / 2.0
  end

  # calculate the z-score of an array
  def self.array_z_score(values)
    mean = values.mean
    stddev = values.stdev
    if stddev === 0.0
      # if the standard deviation is zero, return NaN for all values (to avoid getting Infinity)
      values.map {Float::NAN}
    else
      values.map {|v| (v - mean) / stddev}
    end
  end

  # calculate a z-score for every entry (subtract the mean, divide by the standard deviation)
  # for a given gene based on merged expression scores hash
  def self.z_score(scores, cells)
    values = cells.map {|c| scores[c].to_f}
    self.array_z_score(values)
  end

  # calculate the robust z-score of an array of values
  def self.array_robust_z_score(values)
    median = self.array_median(values)
    deviations = values.map {|v| (v - median).abs}
    # compute median absolute deviation
    mad = self.array_median(deviations)
    if mad === 0.0
      # if the median absolute deviation is zero, return NaN for all values (to avoid getting Infinity)
      values.map {Float::NAN}
    else
      values.map {|v| (v - median) / mad}
    end
  end

  # calculate a robust z-score for every entry (subtract the median, divide by the median absolute deviation)
  # for a given gene based on merged expression scores hash
  def self.robust_z_score(scores, cells)
    values = cells.map {|c| scores[c].to_f}
    self.array_robust_z_score(values)
  end
end
