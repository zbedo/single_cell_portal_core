require "test_helper"

class ParseUtilsTest < ActiveSupport::TestCase

  def setup
    @study = Study.first
  end

  # test parsing 10X CellRanger output
  def test_cell_ranger_expression_parse
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    # control values
    @expected_genes = %w(ATAD3C UTS2 SLC45A1 ACTRT2 NADK KLHL17 MIB2 CPTP HES4 CDK11A MEGF6 DFFB MMP23B VWA1 ARHGEF16 UBE2J2
                         DVL1 AGRN GABRD HES5 WRAP73 PLEKHG5 PARK7 SMIM1 CHD5)
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
    @expected_genes.each do |gene|
      gene = @study.genes.where(name: /#{gene}/).first
      cell_name = gene.scores.keys.first
      value = gene.scores.values.first
      assert value == 1, "Did not find correct score value, expected 1 but found #{value}"
      assert @expected_cells.include?(cell_name), "Cell name '#{cell_name}' was not from control list: #{@expected_cells}"
    end
    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end
end