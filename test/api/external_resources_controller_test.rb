require 'api_test_helper'

class ExternalResourcesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include Requests::JsonHelpers
  include Requests::HttpHelpers

  setup do
    @random_seed = File.open(Rails.root.join('.random_seed')).read.strip
    @user = User.first
    @study = Study.find_by(name: "API Test Study #{@random_seed}")
    @external_resource = @study.external_resources.first
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
                                                                           :provider => 'google_oauth2',
                                                                           :uid => '123545',
                                                                           :email => 'testing.user@gmail.com'
                                                                       })
    sign_in @user
  end

  test 'should get index' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"
    execute_http_request(:get, api_v1_study_external_resources_path(@study))
    assert_response :success
    assert json.size >= 1, 'Did not find any external_resources'
    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test 'should get external resource' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"
    execute_http_request(:get, api_v1_study_external_resource_path(study_id: @study.id, id: @external_resource.id))
    assert_response :success
    # check all attributes against database
    @external_resource.attributes.each do |attribute, value|
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

  # create, update & delete tested together to use new object to avoid delete/update running before create
  test 'should create then update then delete external resource' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"
    # create external_resource
    external_resource_attributes = {
        external_resource: {
            url: 'https://www.something.com',
            title: 'Something'
        }
    }
    execute_http_request(:post, api_v1_study_external_resources_path(study_id: @study.id), external_resource_attributes)
    assert_response :success
    assert json['title'] == external_resource_attributes[:external_resource][:title],
           "Did not set title correctly, expected #{external_resource_attributes[:external_resource][:title]} but found #{json['title']}"
    # update external_resource
    external_resource_id = json['_id']['$oid']
    description = 'This is the description'
    update_attributes = {
        external_resource: {
            description: description
        }
    }
    execute_http_request(:patch, api_v1_study_external_resource_path(study_id: @study.id, id: external_resource_id), update_attributes)
    assert_response :success
    assert json['description'] == update_attributes[:external_resource][:description],
           "Did not set description correctly, expected #{update_attributes[:external_resource][:description]} but found #{json['description']}"
    # delete external_resource
    execute_http_request(:delete, api_v1_study_external_resource_path(study_id: @study.id, id: external_resource_id))
    assert_response 204, "Did not successfully delete external_resource, expected response of 204 but found #{@response.response_code}"
    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end
end
