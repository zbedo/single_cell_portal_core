require 'api_test_helper'

class StudiesControllerControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include Requests::JsonHelpers
  include Requests::HttpHelpers

  setup do
    @user = User.first
    @study = Study.first
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
                                                                           :provider => 'google_oauth2',
                                                                           :uid => '123545',
                                                                           :email => 'testing.user@gmail.com'
                                                                       })
    sign_in @user
  end

  test 'should get index' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"
    execute_http_request(:get, api_v1_studies_path)
    assert_response :success
    assert json.size >= 1, 'Did not find any studies'
    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test 'should get study' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"
    execute_http_request(:get, api_v1_study_path(@study))
    assert_response :success
    # check all attributes against database
    @study.attributes.each do |attribute, value|
      if attribute =~ /_id/
        assert json[attribute] == JSON.parse(value.to_json), "Attribute mismatch: #{attribute} is incorrect, expected #{JSON.parse(value.to_json)} but found #{json[attribute.to_s]}"
      elsif attribute =~ /_at/
        assert DateTime.parse(json[attribute]) == value, "Attribute mismatch: #{attribute} is incorrect, expected #{value} but found #{DateTime.parse(json[attribute])}"
      else
        assert json[attribute] == value, "Attribute mismatch: #{attribute} is incorrect, expected #{value} but found #{json[attribute.to_s]}"
      end
    end
    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  # create, update & delete tested together to use new object rather than main testing study
  test 'should create then update then delete study' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"
    # create study
    study_attributes = {
        study: {
            name: "New Study #{SecureRandom.uuid}"
    }}
    execute_http_request(:post, api_v1_studies_path, study_attributes)
    assert_response :success
    assert json['name'] == study_attributes[:study][:name], "Did not set name correctly, expected #{study_attributes[:study][:name]} but found #{assert json['name']}"
    # update study
    study_id = json['_id']['$oid']
    update_attributes = {
        study: {
            description: "Test description #{SecureRandom.uuid}"
        }
    }
    execute_http_request(:patch, api_v1_study_path(id: study_id), update_attributes)
    assert_response :success
    assert json['description'] == update_attributes[:study][:description], "Did not set name correctly, expected #{update_attributes[:study][:description]} but found #{assert json['description']}"
    # delete study, passing ?workspace=persist to skip FireCloud workspace deletion
    execute_http_request(:delete, api_v1_study_path(id: study_id, workspace: 'persist'))
    assert_response 204, "Did not successfully delete study, expected response of 204 but found #{@response.response_code}"
    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

end