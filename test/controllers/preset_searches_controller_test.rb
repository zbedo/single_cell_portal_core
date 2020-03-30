require "integration_test_helper"

class PresetSearchesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def setup
    @test_user = User.first
    auth_as_user(@test_user)
    sign_in @test_user
    @search = PresetSearch.first
  end

  test "gets index" do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    get preset_searches_path
    assert_response :success
    assert_select 'table#searches', 1, 'Did not preset search table'

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test "gets new" do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    get new_preset_search_path
    assert_response :success
    assert_select 'form#preset-search-form', 1, 'Did not find preset search form'

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test "creates updates and deletes preset search" do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    study_accession = Study.all.sample.accession
    terms = "test data \"this is a phrase\""
    facets = 'disease:MONDO_0000001+species:NCBITaxon_9606'
    preset_search_params = {
        preset_search: {
            name: 'My Preset Search',
            accession_whitelist: study_accession,
            search_terms: terms,
            facet_filters: facets
        }
    }
    post preset_searches_path, params: preset_search_params
    follow_redirect!
    assert_response :success
    @preset_search = PresetSearch.find_by(name: 'My Preset Search')
    assert @preset_search.present?, "Preset search did not get created"
    assert_equal @preset_search.accession_whitelist, [study_accession],
                 "Did not properly set whitelist: #{study_accession} is not in #{@preset_search.accession_whitelist}"
    assert_equal @preset_search.keyword_query_string, terms,
                 "Search terms not correctly set: #{@preset_search.keyword_query_string} != #{terms}"
    assert_equal @preset_search.facet_query_string, facets,
                 "Facets not correctly set: #{@preset_search.facet_query_string} != #{facets}"

    new_terms = 'update'
    update_params = {
        preset_search: {
            search_terms: new_terms,
            facet_filters: facets,
            accession_whitelist: study_accession
        }
    }
    patch preset_search_path(@preset_search), params: update_params
    follow_redirect!
    assert_response :success
    @preset_search.reload
    assert @preset_search.present?, "Preset search did not get loaded"
    assert_equal @preset_search.keyword_query_string, new_terms,
                 "Search terms did not update: #{new_terms} is not in #{@preset_search.keyword_query_string}"
    assert_equal @preset_search.accession_whitelist, [study_accession],
                 "Accession whitelist changed when it shouldn't have; #{study_accession} is not in #{@preset_search.accession_whitelist}"
    assert_equal @preset_search.facet_query_string, facets,
                 "Facets were changed when they shouldn't have; #{facets} != #{@preset_search.facet_query_string}"


    delete preset_search_path(@preset_search)
    follow_redirect!
    assert_response :success
    assert_equal 1, PresetSearch.count, "Did not delete search, expected count of 1 but found #{PresetSearch.count}"

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test "shows preset search" do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    get preset_search_path(@search)
    assert_response :success
    assert_select 'dl#preset-search-attributes', 1, 'Did not find preset search attributes'

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test "gets edit for preset search" do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    get edit_preset_search_path(@search)
    assert_response :success
    assert_select 'form#preset-search-form', 1, 'Did not find preset search form'

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end
end
