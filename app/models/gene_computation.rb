# compute study-wide and cluster-specific means of gene expression values

class GeneComputation

  def self.write_ideogram_annots(study)
    ideogram_annots = self.get_ideogram_annots(study)
    filename = study.url_safe_name + '_exp_means.json'
    file = File.new(filename, 'w+')
    file.write ideogram_annots.to_json
    file.close
  end

  def self.get_ideogram_annots(study)
    puts "Preparing Ideogram.js annotation object for #{study.name}"
    scores = self.compute_gene_exp_means(study)
    genes = self.get_gene_annotations
    cluster_names = scores[0].slice(1, scores[0].length)

    keys =  ['name', 'start', 'length', 'trackIndex', 'id', 'type'].concat(cluster_names)

    annots_by_chr = {}

    scores.slice(1, scores.length).each do | score |
      gene_name = score[0]

      if !genes.key?(gene_name)
        puts "Study gene #{gene_name} not in Ensembl annotation"
        next
      end

      gene = genes[gene_name]
      chr = gene[:chr]
      start = gene[:start].to_i
      stop = gene[:stop].to_i
      length = stop - start
      id = gene[:id]
      type = gene[:type]

      if !annots_by_chr.key?(chr)
        annots_by_chr[chr] = []
      end

      cluster_scores = score.slice(1, scores.length)

      track_index = self.get_track_index(score[1])

      annot = [gene_name, start, length, track_index, id, type] + cluster_scores
      annots_by_chr[chr].push(annot)
    end

    annots_list = []

    annots_by_chr.each do |chr, annots|
      annots_list.push({chr: chr, annots: annots})
    end

    ideogram_annots = {keys: keys, annots: annots_list}

    return ideogram_annots
  end

  def self.get_track_index(score)
    if score > 5
      track_index = 0 # high expression
    elsif score < 2
      track_index = 2 # low expression
    else
      track_index = 1 # medium expression
    end
    return track_index
  end

  def self.compute_gene_exp_means(study)
    puts "computing study-wide and cluster-specific mean gene expression values for #{study.name}"

    scores_lists = []

    clusters = study.cluster_groups

    cluster_names = clusters.map(&:name)
    keys = ['name', 'all'] + cluster_names
    scores_lists.push(keys)

    collapse_genes = study.expression_matrix_files.size > 1
    unique_genes = study.genes.pluck(:name)
    unique_genes.each_with_index do |gene_name, index|
      scores_list = []
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
      scores_list.push(gene_name, val)
      clusters.each do |cluster|
        cells = cluster.concatenate_data_arrays('text', 'cells')
        cluster_scores = scores.select {|cell, val| cells.include?(cell)}
        val = 0.0
        unless cluster_scores.empty?
          val = cluster_scores.values.mean
        end
        scores_list.push(val)
      end
      if index % 100 == 0 && index != 0
        puts "processed #{index} of #{unique_genes.size} genes in #{study.name}"
      end
      scores_lists.push(scores_list)
    end

    puts 'scores_list.length'
    puts scores_lists.length

    return scores_lists

  end


  def self.get_gene_annotations
    genes = {}

    File.open('data/mouse_genes_grcm38p5_ensembl_biomart.tsv', 'r') do |f|
      f.each_line.with_index do |line, index|
        if index == 0
          next
        end
        columns = line.strip().split("\t")
        id, chr, start, stop, name, type = columns
        genes[name] = {
            id: id,
            chr: chr,
            start: start,
            stop: stop,
            type: type
        }
      end
    end

    return genes
  end
end