require "integration_test_helper"

class SearchFacetPopulatorTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test 'populate facets from alexandria convention data' do
    SearchFacet.destroy_all
    SearchFacetPopulator.populate_from_schema
    assert_equal 10, SearchFacet.count

    # spot-check a couple of facets
    disease_facet = SearchFacet.find_by(name: 'disease')
    assert_equal true, disease_facet.is_ontology_based
    assert_equal true, disease_facet.is_array_based
    assert_equal 'https://www.ebi.ac.uk/ols/api/ontologies/mondo', disease_facet.ontology_urls.first['url']

    sex_facet = SearchFacet.find_by(name: 'sex')
    assert_equal false, sex_facet.is_ontology_based
    assert_equal false, sex_facet.is_array_based
    assert_equal [], sex_facet.ontology_urls

  end
end
