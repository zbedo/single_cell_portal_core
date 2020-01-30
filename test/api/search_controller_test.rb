require 'api_test_helper'

class SearchControllerTest < ActionDispatch::IntegrationTest
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
    @random_seed = File.open(Rails.root.join('.random_seed')).read.strip
  end

  test 'should get all search facets' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    execute_http_request(:get, api_v1_search_facets_path)
    assert_response :success
    assert json.size == 1, "Did not find correct number of search facets, expected 1 but found #{json.size}"

    puts "#{File.basename(__FILE__)}: #{self.method_name} completed!"
  end

  test 'should search facet filters' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    @search_facet = SearchFacet.first
    filter = @search_facet.filters.first
    valid_query = filter[:name]
    execute_http_request(:get, api_v1_search_facet_filters_path(facet: @search_facet.identifier, query: valid_query))
    assert_response :success
    assert json['query'] == valid_query, "Did not search on correct value; expected #{valid_query} but found #{json['query']}"
    assert json['filters'].first == filter, "Did not find expected filter of #{filter} in response: #{json['filters']}"
    invalid_query = 'does not exist'
    execute_http_request(:get, api_v1_search_facet_filters_path(facet: @search_facet.identifier, query: invalid_query))
    assert_response :success
    assert json['query'] == invalid_query, "Did not search on correct value; expected #{invalid_query} but found #{json['query']}"
    assert json['filters'].size == 0, "Should have found no filters; expected 0 but found #{json['filters'].size}"

    puts "#{File.basename(__FILE__)}: #{self.method_name} completed!"
  end
end
