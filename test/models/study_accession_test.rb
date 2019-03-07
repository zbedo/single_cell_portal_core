require "test_helper"

describe StudyAccession do
  let(:study_accession) { StudyAccession.new }

  it "must be valid" do
    value(study_accession).must_be :valid?
  end
end
