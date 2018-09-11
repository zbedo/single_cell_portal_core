require "test_helper"

describe GenomeAssembly do
  let(:genome_assembly) { GenomeAssembly.new }

  it "must be valid" do
    value(genome_assembly).must_be :valid?
  end
end
