require 'api_test_helper'

class StudyFileBundlesControllerControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include Requests::JsonHelpers
  include Requests::HttpHelpers

  setup do
    @user = User.first
    @study = Study.find_by(name: 'API Test Study')
    @study_file_bundle = @study.study_file_bundles.first
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
                                                                           :provider => 'google_oauth2',
                                                                           :uid => '123545',
                                                                           :email => 'testing.user@gmail.com'
                                                                       })
    sign_in @user
  end

  test 'should get index' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"
    execute_http_request(:get, api_v1_study_study_file_bundles_path(@study))
    assert_response :success
    assert json.size >= 1, 'Did not find any study_file_bundles'
    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test 'should get study file bundle' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"
    execute_http_request(:get, api_v1_study_study_file_bundle_path(study_id: @study.id, id: @study_file_bundle.id))
    assert_response :success
    # check all attributes against database
    @study_file_bundle.attributes.each do |attribute, value|
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

  # create & delete tested together to use new object to avoid delete running before create
  test 'should create then delete study file bundle' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"
    # create study file bundle
    study_file_bundle_attributes = {
        'study_file_bundle' => {
            'original_file_list' => [
                {'name' => 'matrix.mtx', 'file_type' => 'MM Coordinate Matrix' },
                {'name' => 'genes.tsv', 'file_type' => '10X Genes File' },
                {'name' => 'barcodes.tsv', 'file_type' => '10X Barcodes File' }
            ]
        }
    }
    execute_http_request(:post, api_v1_study_study_file_bundles_path(study_id: @study.id), study_file_bundle_attributes)
    assert_response :success
    assert json['original_file_list'] == study_file_bundle_attributes['study_file_bundle']['original_file_list'],
           "Did not set name correctly, expected #{study_file_bundle_attributes['study_file_bundle']['original_file_list']} but found #{json['original_file_list']}"
    # delete study file bundle
    study_file_bundle_id = json['_id']['$oid']
    execute_http_request(:delete, api_v1_study_study_file_bundle_path(study_id: @study.id, id: study_file_bundle_id))
    assert_response 204, "Did not successfully delete study file bundle, expected response of 204 but found #{@response.response_code}"
    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end
end