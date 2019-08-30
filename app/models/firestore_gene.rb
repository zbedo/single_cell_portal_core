class FirestoreGene
  include ActiveModel::AttributeAssignment
  include FirestoreDocuments
  include FirestoreSubDocuments

  attr_accessor :name, :searchable_name, :gene_id, :study_accession, :taxon_name, :taxon_common_name, :ncbi_taxid,
                :genome_assembly_accession, :genome_annotation, :file_id, :document

  def self.collection_name
    :genes
  end

  def self.sub_collection_name
    :gene_expression
  end

  # overwrites module method to allow for name/searchable_name query
  # search by case-sensitive name first, and then case-insensitive, then by gene ID
  # return results as a hash to be compliant with current functionality
  def self.by_study_and_name(accession, name)
    merged_scores = {'searchable_name' => name.downcase, 'name' => name, 'scores' => {}}
    docs = self.query_by(study_accession: accession, name: name)
    unless docs.any?
      docs = self.query_by(study_accession: accession, searchable_name: name.downcase)
    end
    unless docs.any?
      docs = self.query_by(study_accession: accession, gene_id: name)
    end
    if docs.any?
      docs.each do |doc|
        gene = self.new(doc)
        merged_scores['scores'].merge!(gene.scores)
      end
      merged_scores
    else
      {}
    end
  end

  # return all unique gene names
  def self.unique_genes(accession)
    self.by_study(accession).map(&:autocomplete_label)
  end

  def scores
    self.sub_documents_as_hash(:cell_names, :expression_scores)
  end

  def autocomplete_label
    self.gene_id.blank? ? self.name : "#{self.name} (#{self.gene_id})"
  end

  def taxon
    self.study_file.taxon
  end

  def species
    self.taxon
  end

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


  def self.test_ingest(num_genes=1000)
    print "Populating #{num_genes} genes into Firestore... "
    accession = 'SCPTEST'
    file_id = 'performace_test'
    genes = Gene.pluck(:name).shuffle.take(num_genes)
    slice_size = num_genes / 10
    start_time = Time.now
    Parallel.map(genes.each_slice(slice_size), in_threads: 10) do |slice|
      self.client.batch do |b|
        slice.each do |gene|
          b.set("genes/#{gene}", {name: gene, study_accession: accession, file_id: file_id})
        end
      end
    end
    end_time = Time.now
    runtime = TimeDifference.between(start_time, end_time).humanize
    puts "Completed!"
    puts "Total runtime to ingest #{num_genes} genes: #{runtime}"
  end

  def self.test_delete(num_threads=10)
    accession = 'SCPTEST'
    file_id = 'performace_test'
    genes_found = self.count(study_accession: accession, file_id: file_id)
    print "Preparing to delete #{genes_found} genes from Firestore in #{num_threads} threads... "
    start_time = Time.now
    self.delete_by_study_and_file(accession, file_id, num_threads)
    end_time = Time.now
    runtime = TimeDifference.between(start_time, end_time).humanize
    puts "Completed!"
    puts "Total runtime to delete #{genes_found} genes: #{runtime}"
  end
end
