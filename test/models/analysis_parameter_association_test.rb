require "test_helper"

describe AnalysisParameterAssociation do
  let(:analysis_parameter_association) { AnalysisParameterAssociation.new }

  it "must be valid" do
    value(analysis_parameter_association).must_be :valid?
  end
end
