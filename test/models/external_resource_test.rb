require "test_helper"

describe ExternalResource do
  let(:external_resource) { ExternalResource.new }

  it "must be valid" do
    value(external_resource).must_be :valid?
  end
end
