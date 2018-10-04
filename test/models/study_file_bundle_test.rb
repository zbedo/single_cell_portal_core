require "test_helper"

describe StudyFileBundle do
  let(:study_file_bundle) { StudyFileBundle.new }

  it "must be valid" do
    value(study_file_bundle).must_be :valid?
  end
end
