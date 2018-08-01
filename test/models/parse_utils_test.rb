require "test_helper"

class ParseUtilsTest < ActiveSupport::TestCase

  def setup
    @study = Study.first
  end

  # test parsing 10X CellRanger output
  def test_cell_ranger_expression_parse
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    # control values
    @expected_genes = %w(KLHL17 HES4 AGRN UBE2J2 CPTP DVL1 VWA1 ATAD3C MIB2 MMP23B CDK11A NADK GABRD HES5 ACTRT2 ARHGEF16
                         MEGF6 WRAP73 SMIM1 DFFB CHD5 PLEKHG5 UTS2 PARK7)
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
    puts 'Parsing 10X GRCh38 output...'
    ParseUtils.cell_ranger_expression_parse(@study, user, matrix, genes, barcodes, {skip_upload: true})
    puts 'Parse of 10X GRCh38 complete'
    # validate that the expected significant values have been created
    @expected_genes.each_with_index do |gene, index|
      gene = @study.genes.where(name: /#{gene}/).first
      cell_name = gene.scores.keys.first
      value = gene.scores.values.first
      assert value == index + 1, "Did not find correct score value for #{gene.name}:#{cell_name}, expected #{index + 1} but found #{value}"
      assert @expected_cells.include?(cell_name), "Cell name '#{cell_name}' was not from control list: #{@expected_cells}"
    end
    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end
end