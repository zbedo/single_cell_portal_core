# compute study-wide and cluster-specific means of gene expression values

class GeneComputation
  def self.compute_gene_exp_means(study)
    puts "computing study-wide and cluster-specific mean gene expression values for #{study.name}"
    clusters = study.cluster_groups
    cluster_names = clusters.map(&:name)
    filename = study.url_safe_name + '_exp_means.txt'
    file = File.new(filename, 'w+')
    headers = ['GENE', 'All Cells'] + cluster_names
    file.write headers.join("\t") + "\n"
    collapse_genes = study.expression_matrix_files.size > 1
    unique_genes = study.genes.pluck(:name)
    unique_genes.each_with_index do |gene_name, index|
      scores = {}
      if collapse_genes
        scores = study.genes.by_name(gene_name, study.expression_matrix_files.map(&:id)).first['scores']
      else
        scores = Gene.find_by(name: gene_name, study_id: study.id).scores
      end
      val = 0.0
      unless scores.empty?
        val = scores.values.mean
      end
      file.write "#{gene_name}\t#{val}"
      clusters.each do |cluster|
        cells = cluster.concatenate_data_arrays('text', 'cells')
        cluster_scores = scores.select {|cell, val| cells.include?(cell)}
        val = 0.0
        unless cluster_scores.empty?
          val = cluster_scores.values.mean
        end
        file.write "\t#{val}"
      end
      file.write "\n"
      if index % 100 == 0 && index != 0
        puts "processed #{index} of #{unique_genes.size} genes in #{study.name}"
      end
    end
    file.close
  end
end