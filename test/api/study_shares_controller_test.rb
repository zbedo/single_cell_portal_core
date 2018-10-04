require 'api_test_helper'

class StudySharesControllerControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include Requests::JsonHelpers
  include Requests::HttpHelpers

  setup do
    @user = User.first
    @study = Study.find_by(name: 'API Test Study')
    @study_share = @study.study_shares.first
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
                                                                           :provider => 'google_oauth2',
                                                                           :uid => '123545',
                                                                           :email => 'testing.user@gmail.com'
                                                                       })
    sign_in @user
  end

  test 'should get index' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"
    execute_http_request(:get, api_v1_study_study_shares_path(@study))
    assert_response :success
    assert json.size >= 1, 'Did not find any study_shares'
    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test 'should get study share' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"
    execute_http_request(:get, api_v1_study_study_share_path(study_id: @study.id, id: @study_share.id))
    assert_response :success
    # check all attributes against database
    @study_share.attributes.each do |attribute, value|
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
  test 'should create then update then delete study share' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"
    # create study share
    study_share_attributes = {
        study_share: {
            email: 'some.person@gmail.com',
            permission: 'Reviewer'
        }
    }
    execute_http_request(:post, api_v1_study_study_shares_path(study_id: @study.id), study_share_attributes)
    assert_response :success
    assert json['email'] == study_share_attributes[:study_share][:email], "Did not set email correctly, expected #{study_share_attributes[:study_share][:email]} but found #{json['email']}"
    # update study share
    study_share_id = json['_id']['$oid']
    update_attributes = {
        study_share: {
            deliver_emails: false
        }
    }
    execute_http_request(:patch, api_v1_study_study_share_path(study_id: @study.id, id: study_share_id), update_attributes)
    assert_response :success
    assert json['deliver_emails'] == update_attributes[:study_share][:deliver_emails], "Did not set deliver_emails correctly, expected #{update_attributes[:study_share][:deliver_emails]} but found #{json['deliver_emails']}"
    # delete study share
    execute_http_request(:delete, api_v1_study_study_share_path(study_id: @study.id, id: study_share_id))
    assert_response 204, "Did not successfully delete study file, expected response of 204 but found #{@response.response_code}"
    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end
end