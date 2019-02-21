require "test_helper"

describe AnalysisParameterFilter do
  let(:analysis_parameter_filter) { AnalysisParameterFilter.new }

  it "must be valid" do
    value(analysis_parameter_filter).must_be :valid?
  end
end
