require "test_helper"

class StudyFileTest < ActiveSupport::TestCase
  def study_file
    @study_file ||= StudyFile.new
  end
end
