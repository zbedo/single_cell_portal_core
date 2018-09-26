require "test_helper"

describe Taxon do
  let(:taxon) { Taxon.new }

  it "must be valid" do
    value(taxon).must_be :valid?
  end
end
