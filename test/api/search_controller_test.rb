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

    facet_count = SearchFacet.count
    execute_http_request(:get, api_v1_search_facets_path)
    assert_response :success
    assert json.size == facet_count, "Did not find correct number of search facets, expected #{facet_count} but found #{json.size}"

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test 'should search facet filters' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    @search_facet = SearchFacet.first
    filter = @search_facet.filters.first
    valid_query = filter[:name]
    execute_http_request(:get, api_v1_search_facet_filters_path(facet: @search_facet.identifier, query: valid_query))
    assert_response :success
    assert_equal json['query'], valid_query, "Did not search on correct value; expected #{valid_query} but found #{json['query']}"
    assert_equal json['filters'].first, filter, "Did not find expected filter of #{filter} in response: #{json['filters']}"
    invalid_query = 'does not exist'
    execute_http_request(:get, api_v1_search_facet_filters_path(facet: @search_facet.identifier, query: invalid_query))
    assert_response :success
    assert_equal json['query'], invalid_query, "Did not search on correct value; expected #{invalid_query} but found #{json['query']}"
    assert_equal json['filters'].size, 0, "Should have found no filters; expected 0 but found #{json['filters'].size}"

    puts "#{File.basename(__FILE__)}: #{self.method_name} completed!"
  end

  test 'should return search results using facets' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    study = Study.find_by(name: "Test Study #{@random_seed}")
    facets = SearchFacet.all
    # format facet query string; this will be done by the search UI in production
    facet_queries = facets.map {|facet| [facet.identifier, facet.filters.map {|f| f[:id]}.join(',')]}
    facet_query = facet_queries.map {|query| query.join(':')}.join('+')
    execute_http_request(:get, api_v1_search_path(type: 'study', facets: facet_query))
    assert_response :success
    study_count = json['studies'].size
    assert_equal study_count, 1, "Did not find correct number of studies, expected 1 but found #{study_count}"
    result_accession = json['studies'].first['accession']
    assert_equal result_accession, study.accession, "Did not find correct study; expected #{study.accession} but found #{result_accession}"

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test 'should return search results using keywords' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    study_count = Study.count
    execute_http_request(:get, api_v1_search_path(type: 'study', terms: @random_seed))
    assert_response :success
    result_count = json['studies'].size
    assert_equal study_count, result_count, "Did not find correct number of studies, expected #{study_count} but found #{result_count}"

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end
end
