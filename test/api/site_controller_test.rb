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
    assert json.size >= 3, "Did not find correct number of studies, expected 3 or more but found #{json.size}"

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test 'should get one study' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    @study = Study.find_by(name: 'API Test Study')
    execute_http_request(:get, api_v1_site_study_view_path(accession: @study.accession))
    assert_response :success
    assert json['study_files'].size == 3, "Did not find correct number of files, expected 3 but found #{json['study_files'].size}"

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test 'should get all analyses' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"
    execute_http_request(:get, api_v1_site_analyses_path)
    assert_response :success
    assert json.size == 1, "Did not find correct number of analyses, expected 1 but found #{json.size}"
    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test 'should get one analysis' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"
    @analysis_configuration = AnalysisConfiguration.first
    execute_http_request(:get, api_v1_site_get_analysis_path(namespace: @analysis_configuration.namespace,
                                                             name: @analysis_configuration.name,
                                                             snapshot: @analysis_configuration.snapshot))
    assert_response :success
    assert json['name'] == @analysis_configuration.name,
           "Did not load correct analysis name, expected '#{@analysis_configuration.name}' but found '#{json['name']}'"
    assert json['required_inputs'] == @analysis_configuration.required_inputs(true),
           "Required inputs do not match; expected '#{@analysis_configuration.required_inputs(true)}' but found #{json['required_inputs']}"
    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end
end
