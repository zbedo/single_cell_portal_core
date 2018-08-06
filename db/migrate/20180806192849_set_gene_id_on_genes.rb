class SetGeneIdOnGenes < Mongoid::Migration
  def self.up
    study_files = StudyFile.where(file_type: 'MM Coordinate Matrix')
    study_file_count = study_files.count
    study_files.each_with_index do |study_file, study_file_index|
      genes = Gene.where(study_id: study_file.study.id, study_file_id: study_file.id, gene_id: nil) # only process genes without a gene_id
      gene_count = genes.count
      genes.each_with_index do |gene, gene_index|
        current_name = gene.name
        new_name, gene_id = current_name.split('(').map {|entry| entry.strip.chomp(')')}
        gene.update(name: new_name, searchable_name: new_name.downcase, gene_id: gene_id)
        if (gene_index + 1) % 1000 == 0
          Rails.logger.info "Processed #{gene_index + 1}/#{gene_count} records from file #{study_file_index + 1} of #{study_file_count}"
        end
      end
    end
    Rails.logger.info "Migration complete"
  end

  def self.down
    genes = Gene.where(:gene_id.nin => [nil])
    gene_count = genes.count
    genes.each_with_index do |gene, gene_index|
      old_name = "#{gene.name} (#{gene.gene_id})"
      gene.update(name: old_name, searchable_name: old_name.downcase, gene_id: nil)
      if (gene_index + 1) % 1000 == 0
        Rails.logger.info "Processed #{gene_index + 1}/#{gene_count} records"
      end
    end
    Rails.logger.info "Rollback complete"
  end
end