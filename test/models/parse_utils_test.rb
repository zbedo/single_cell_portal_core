require "test_helper"

class ParseUtilsTest < ActiveSupport::TestCase

  def setup
    @study = Study.first
  end

  # test parsing 10X CellRanger output
  def test_cell_ranger_expression_parse
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    # control values
    @expected_genes = %w(HMGN2 ARF1 PPM1G EIF1B LSM6 RPS14 TAF6 GNB2 RPL10 VDAC3 EIF3E EEF1D RPP25L PPP1CA MRPL51 RPS26
                         SUCLA2 HSP90AA1 RPLP1 MPHOSPH6 RPL23 RPS15 PIN1 RPL13A MT-CO2)
    @expected_cells = %w(AACGTTGGTTAAAGTG-1 AGTAGTCAGAGCTATA-1 ATCTGCCCATACTCTT-1 ATGCGATCAAGTTGTC-1 ATTTCTGTCCTTTCGG-1
                         CAGTAACGTAAACACA-1 CCAATCCCATGAAGTA-1 CGTAGGCCAGCGAACA-1 CTAACTTGTTCCATGA-1 CTCCTAGGTCTCATCC-1
                         CTCGGAGTCGTAGGAG-1 CTGAAACAGGGAAACA-1 GACTACAGTAACGCGA-1 GCATACAGTACCGTTA-1 GCGAGAACAAGAGGCT-1
                         GCTTCCACAGCTGTAT-1 GCTTGAAAGAGCTGCA-1 GGACGTCGTTAAAGAC-1 GTACTCCCACTGTTAG-1 GTCACAAAGTAAGTAC-1
                         TAGCCGGAGAGACGAA-1 TCAACGACACAGCCCA-1 TCGGGACGTCTCAACA-1 TCTCTAACATGCTGGC-1 TGAGCCGGTGATAAGT-1)

    # initiate parse
    matrix = @study.study_files.by_type('MM Coordinate Matrix').first
    genes = @study.study_files.by_type('10X Genes File').first
    barcodes = @study.study_files.by_type('10X Barcodes File').first
    user = User.first
    puts 'Parsing 10X GRCh38 output (this will take a few minutes)...'
    ParseUtils.cell_ranger_expression_parse(@study, user, matrix, genes, barcodes, {skip_upload: true, local: true})
    puts 'Parse of 10X GRCh38 complete'
    # validate that the expected significant values have been created
    @expected_genes.each do |gene|
      gene = @study.genes.where(name: gene).first
      cell_name = gene.scores.keys.first
      value = gene.scores.values.first
      assert value == 1, "Did not find correct score value, expected 1 but found #{value}"
      assert @expected_cells.include?(cell_name), "Cell name '#{cell_name}' was not from control list: #{@expected_cells}"
    end
    assert @study.all_cells_array.sort == @expected_cells.sort, "All cells array for study does not match match expected cells list: #{@study.all_cells_array.sort} vs. #{@expected_cells.sort}"
    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end
end