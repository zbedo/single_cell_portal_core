require 'api_test_helper'

class SearchControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include Requests::JsonHelpers
  include Requests::HttpHelpers

  setup do
    @user = User.find_by(email: 'testing.user.2@gmail.com')
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
    matched_facets = json['studies'].first['facet_matches'].keys.sort
    matched_facets.delete_if {|facet| facet == 'facet_search_weight'} # remove search weight as it is not relevant
    source_facets = facets.map(&:identifier).sort
    assert_equal source_facets, matched_facets, "Did not match on correct facets; expected #{source_facets} but found #{matched_facets}"

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test 'should return search results using keywords' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    study_count = Study.count
    execute_http_request(:get, api_v1_search_path(type: 'study', terms: @random_seed))
    assert_response :success
    result_count = json['studies'].size
    assert_equal study_count, result_count, "Did not find correct number of studies, expected #{study_count} but found #{result_count}"
    assert_equal @random_seed, json['studies'].first['term_matches']

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  # should generate an auth code for a given user
  test 'should generate auth code' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    execute_http_request(:post, api_v1_create_auth_code_path)
    assert_response :success
    assert_not_nil json['totat'], "Did not generate auth code; missing 'totat' field: #{json}"
    auth_code = json['totat']
    @user.reload
    assert_equal auth_code, @user.totat

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  # should generate a config text file to pass to curl for bulk download
  test 'should generate curl config for bulk download' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    study = Study.find_by(name: "Test Study #{@random_seed}")
    file_types = %w(Expression Metadata).join(',')
    execute_http_request(:post, api_v1_create_auth_code_path)
    assert_response :success
    auth_code = json['totat']

    files = study.study_files.by_type(['Expression Matrix', 'Metadata'])
    filenames = files.map(&:upload_file_name)
    execute_http_request(:get, api_v1_search_bulk_download_path(
        auth_code: auth_code, accessions: study.accession, file_types: file_types)
    )
    assert_response :success

    config_file = json
    files.each do |file|
      filename = file.upload_file_name
      assert config_file.include?(filename), "Did not find URL for filename: #{filename}"
      output_path = file.bulk_download_pathname
      assert config_file.include?(output_path), "Did not correctly set output path for #{filename} to #{output_path}"
    end

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end
end
