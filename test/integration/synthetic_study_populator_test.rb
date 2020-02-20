require "integration_test_helper"

class SyntheticStudyPopulatorTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  # commented out pending resolution of namespace conflict issue
  # test 'should be able to populate a study with convention metadata' do
  #   SYNTH_STUDY_INFO = {
  #     name: 'HIV in bovine blood',
  #     folder: 'cow_blood'
  #   }

  #   if Study.find_by(name: SYNTH_STUDY_INFO[:name])
  #     Study.find_by(name: SYNTH_STUDY_INFO[:name]).destroy_and_remove_workspace
  #   end

  #   assert_nil Study.find_by(name: SYNTH_STUDY_INFO[:name])

  #   SyntheticStudyPopulator.populate(SYNTH_STUDY_INFO[:folder])
  #   sleep 60
  #   assert_equal 1, Study.find_by(name: SYNTH_STUDY_INFO[:name])

  #   Study.find_by(name: SYNTH_STUDY_INFO[:name]).destroy_and_remove_workspace
  # end
end
