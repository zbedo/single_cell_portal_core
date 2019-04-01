require 'api_test_helper'

class DirectoryListingsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include Requests::JsonHelpers
  include Requests::HttpHelpers

  setup do
    @user = User.first
    @study = Study.find_by(name: 'API Test Study')
    @directory_listing = @study.directory_listings.first
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
                                                                           :provider => 'google_oauth2',
                                                                           :uid => '123545',
                                                                           :email => 'testing.user@gmail.com'
                                                                       })
    sign_in @user
  end

  test 'should get index' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"
    execute_http_request(:get, api_v1_study_directory_listings_path(@study))
    assert_response :success
    assert json.size >= 1, 'Did not find any directory_listings'
    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test 'should get directory listing' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"
    execute_http_request(:get, api_v1_study_directory_listing_path(study_id: @study.id, id: @directory_listing.id))
    assert_response :success
    # check all attributes against database
    @directory_listing.attributes.each do |attribute, value|
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
  test 'should create then update then delete directory listing' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"
    # create directory listing
    files = []
    1.upto(5) do |i|
      files << {
          "name" => "exp_#{i}.gct",
          "size" => i * 100,
          "generation" => "#{SecureRandom.random_number.to_s.split('.').last[0..15]}"
      }
    end
    directory_listing_attributes = {
        "directory_listing" => {
            "name" => 'some_dir',
            "file_type" => 'gct',
            "files" =>  files
        }
    }
    execute_http_request(:post, api_v1_study_directory_listings_path(study_id: @study.id), directory_listing_attributes)
    assert_response :success
    assert json['name'] == directory_listing_attributes["directory_listing"]["name"], "Did not set name correctly, expected #{directory_listing_attributes["directory_listing"]["name"]} but found #{json['name']}"
    # update directory listing
    directory_listing_id = json['_id']['$oid']
    new_file = {
        "name" => 'exp_6.gct',
        "size" => 600,
        "generation" => "#{SecureRandom.random_number.to_s.split('.').last[0..15]}"
    }
    files << new_file
    update_attributes = {
        "directory_listing" => {
            "sync_status" => false,
            "files" => files
        }
    }
    execute_http_request(:patch, api_v1_study_directory_listing_path(study_id: @study.id, id: directory_listing_id), update_attributes)
    assert_response :success
    assert json['sync_status'] == update_attributes["directory_listing"]["sync_status"], "Did not set sync_status correctly, expected #{update_attributes["directory_listing"]["sync_status"]} but found #{json['sync_status']}"
    assert json['files'] == update_attributes["directory_listing"]["files"], "Did not set files correctly, expected #{update_attributes["directory_listing"]["files"]} but found #{json['files']}"
    # delete directory listing
    execute_http_request(:delete, api_v1_study_directory_listing_path(study_id: @study.id, id: directory_listing_id))
    assert_response 204, "Did not successfully delete study file, expected response of 204 but found #{@response.response_code}"
    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end
end