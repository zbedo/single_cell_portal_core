require 'api_test_helper'

class SiteControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include Requests::JsonHelpers
  include Requests::HttpHelpers

  setup do
    @user = User.first
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
                                                                           :provider => 'google_oauth2',
                                                                           :uid => '123545',
                                                                           :email => 'testing.user@gmail.com'
                                                                       })
    sign_in @user
  end

  test 'should get all studies' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    execute_http_request(:get, api_v1_site_studies_path)
    assert_response :success
    assert json.size == 3, "Did not find correct number of studies, expected 3 but found #{json.size}"

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test 'should get one study' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    @study = Study.find_by(name: 'API Test Study')
    execute_http_request(:get, api_v1_site_view_study_path(accession: @study.accession))
    assert_response :success
    assert json['study_files'].size == 3, "Did not find correct number of files, expected 3 but found #{json['study_files'].size}"

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end
end
