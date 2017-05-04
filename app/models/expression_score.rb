class ExpressionScore
  include Mongoid::Document

  belongs_to :study
  belongs_to :study_file

  field :gene, type: String
  field :searchable_gene, type: String
  field :scores, type: Hash

  index({ gene: 1, study_id: 1 }, { unique: true })
  index({ searchable_gene: 1, study_id: 1 }, { unique: false })
  index({ study_id: 1 }, { unique: false })
  index({ study_id: 1, study_file_id: 1} , { unique: false })

  validates_uniqueness_of :gene, scope: :study_id
  validates_presence_of :gene, :scores

  def mean(cells)
    sum = 0.0
    cells.each do |cell|
      sum += self.scores[cell].to_f
    end
    sum / cells.size
  end

  def self.generate_searchable_genes
    records = []
    counter = 0
    self.all.each do |exp_score|
      if exp_score.searchable_gene.nil? || exp_score.searchable_gene.blank?
        exp_score.searchable_gene = exp_score.gene.downcase
        records << exp_score
        counter += 1
        if records.size % 1000 == 0
          self.update(records)
          puts "Updating #{counter} records"
          records = []
        end
      end
    end
    self.update(records)
    puts "Updating #{counter} records"
    records = []
  end
end
