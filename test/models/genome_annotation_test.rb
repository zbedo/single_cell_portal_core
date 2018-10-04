require "test_helper"

describe GenomeAnnotation do
  let(:genome_annotation) { GenomeAnnotation.new }

  it "must be valid" do
    value(genome_annotation).must_be :valid?
  end
end
