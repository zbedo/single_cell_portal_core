require 'api_test_helper'

class StudyFilesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include Requests::JsonHelpers
  include Requests::HttpHelpers

  setup do
    @random_seed = File.open(Rails.root.join('.random_seed')).read.strip
    @user = User.first
    @study = Study.find_by(name: "API Test Study #{@random_seed}")
    @study_file = @study.study_files.first
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
                                                                           :provider => 'google_oauth2',
                                                                           :uid => '123545',
                                                                           :email => 'testing.user@gmail.com'
                                                                       })
    sign_in @user
  end

  test 'should get index' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"
    execute_http_request(:get, api_v1_study_study_files_path(@study))
    assert_response :success
    assert json.size >= 1, 'Did not find any study_files'
    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test 'should get study file' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"
    execute_http_request(:get, api_v1_study_study_file_path(study_id: @study.id, id: @study_file.id))
    assert_response :success
    # check all attributes against database
    @study_file.attributes.each do |attribute, value|
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
  test 'should create then update then delete study file' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"
    # create study file
    study_file_attributes = {
        study_file: {
            upload_file_name: 'table_1.xlsx',
            upload_content_type: 'application/octet-stream',
            upload_file_size: 41692,
            file_type: 'Other'
        }
    }
    execute_http_request(:post, api_v1_study_study_files_path(study_id: @study.id), study_file_attributes)
    assert_response :success
    assert json['name'] == study_file_attributes[:study_file][:upload_file_name], "Did not set name correctly, expected #{study_file_attributes[:study_file][:upload_file_name]} but found #{json['name']}"
    # update study file
    study_file_id = json['_id']['$oid']
    update_attributes = {
        study_file: {
            description: "Test description #{SecureRandom.uuid}"
        }
    }
    execute_http_request(:patch, api_v1_study_study_file_path(study_id: @study.id, id: study_file_id), update_attributes)
    assert_response :success
    assert json['description'] == update_attributes[:study_file][:description], "Did not set description correctly, expected #{update_attributes[:study_file][:description]} but found #{json['description']}"
    # delete study file
    execute_http_request(:delete, api_v1_study_study_file_path(study_id: @study.id, id: study_file_id))
    assert_response 204, "Did not successfully delete study file, expected response of 204 but found #{@response.response_code}"
    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  # create a study file bundle using the study_files_controller method
  test 'should create study file bundle' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    study_file_bundle_attributes = {
        'files' => [
            {'name' => 'cluster.tsv', 'file_type' => 'Cluster' },
            {'name' => 'labels.tsv', 'file_type' => 'Coordinate Labels' }
        ]
    }
    execute_http_request(:post, api_v1_study_study_files_bundle_files_path(study_id: @study.id), study_file_bundle_attributes)
    assert_response :success
    assert json['original_file_list'] == study_file_bundle_attributes['files'],
           "Did not set name correctly, expected #{study_file_bundle_attributes['files']} but found #{json['original_file_list']}"
    # delete study file bundle
    study_file_bundle_id = json['_id']['$oid']
    execute_http_request(:delete, api_v1_study_study_file_bundle_path(study_id: @study.id, id: study_file_bundle_id))
    assert_response 204, "Did not successfully delete study file bundle, expected response of 204 but found #{@response.response_code}"

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test 'should parse study file' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}!"
    execute_http_request(:post, parse_api_v1_study_study_file_path(study_id: @study.id, id: @study_file.id))
    assert_response 204
    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end
end