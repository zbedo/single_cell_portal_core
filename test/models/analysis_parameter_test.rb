require "test_helper"

describe AnalysisParameter do
  let(:analysis_parameter) { AnalysisParameter.new }

  it "must be valid" do
    value(analysis_parameter).must_be :valid?
  end
end
