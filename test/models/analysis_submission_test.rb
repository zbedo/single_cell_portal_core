require "test_helper"

describe AnalysisSubmission do
  let(:analysis_submission) { AnalysisSubmission.new }

  it "must be valid" do
    value(analysis_submission).must_be :valid?
  end
end
