require "test_helper"

class ParseUtilsTest < ActiveSupport::TestCase

  def setup
    @study = Study.first
  end

  # test parsing 10X CellRanger output
  def test_cell_ranger_expression_parse
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    # load study files
    matrix = @study.study_files.by_type('MM Coordinate Matrix').first
    genes = @study.study_files.by_type('10X Genes File').first
    barcodes = @study.study_files.by_type('10X Barcodes File').first

    # control values
    @expected_genes = File.open(genes.upload.path).readlines.map {|line| line.split.map(&:strip)}
    @expected_cells = File.open(barcodes.upload.path).readlines.map(&:strip)
    matrix_file = File.open(matrix.upload.path).readlines
    matrix_file.shift(3) # discard header lines
    expressed_gene_idx = matrix_file.map {|line| line.split.first.strip.to_i}
    @expressed_genes = expressed_gene_idx.map {|idx| @expected_genes[idx - 1].last}

    # initiate parse

    user = User.first
    puts 'Parsing 10X GRCh38 output...'
    ParseUtils.cell_ranger_expression_parse(@study, user, matrix, genes, barcodes, {skip_upload: true})
    puts 'Parse of 10X GRCh38 complete'
    # validate that the expected significant values have been created
    @expected_genes.each do |entry|
      gene_id, gene_name = entry
      gene = @study.genes.find_by(name: gene_name)
      assert gene_name == gene.name, "Gene names do not match: #{gene_name}, #{gene.name}"
      assert gene_id == gene.gene_id, "Gene IDs do not match: #{gene_id}, #{gene.gene_id}"
      # if this gene is expected to have expression, then validate the score is correct
      if @expressed_genes.include?(gene_name)
        expected_value = @expressed_genes.index(gene_name) + 1
        cell_name = gene.scores.keys.first
        assert @expected_cells.include?(cell_name), "Cell name '#{cell_name}' was not from control list: #{@expected_cells}"
        value = gene.scores.values.first
        assert value == expected_value, "Did not find correct score value for #{gene.name}:#{cell_name}, expected #{expected_value} but found #{value}"
      end
    end
    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end
end