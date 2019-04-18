require "integration_test_helper"

class SiteControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def setup
    @test_user = User.find_by(email: 'testing.user@gmail.com')
    auth_as_user(@test_user)
    sign_in @test_user
    @study = Study.first
  end

  test 'should redirect to correct study name url' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    correct_study_url = view_study_path(accession: @study.accession, study_name: @study.url_safe_name)
    incorrect_study_url = view_study_path(accession: @study.accession, study_name: "bogus_name")
    get incorrect_study_url
    assert_response 302, 'Did not redirect to correct url'
    assert_redirected_to correct_study_url,  "Url did not redirected successfully"
    follow_redirect!
    assert_equal(correct_study_url, path, "Url is #{path}. Expected #{correct_study_url}")
    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end


end
