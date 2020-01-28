require "test_helper"

class SearchFacetTest < ActiveSupport::TestCase

  def setup
    @search_facet = SearchFacet.new(
        name: 'Species',
        filters: [
            {id: 'NCBITaxon_9606', name: 'Homo sapiens'}
        ],
        is_ontology_based: true,
        is_array_based: false,
        big_query_id_column: 'species',
        big_query_name_column: 'species__ontology_label',
        convention_name: 'alexandria_convention',
        convention_version: '1.1.3'
    )

    # filter_results to return from mock call to BigQuery
    @filter_results = [
        {id: 'NCBITaxon_9606', name: 'Homo sapiens'},
        {id: 'NCBITaxon_10090', name: 'Mus musculus'}
    ]
  end

  # should return expected filters list
  # mocks call to BigQuery to avoid unnecessary overhead
  test 'should update filters list' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    # mock call to BQ, until a better library can be found
    mock = Minitest::Mock.new
    mock.expect :query, @filter_results, [String]

    SearchFacet.stub :big_query_dataset, mock do

      @search_facet.update_filter_values!

      assert_equal @filter_results, @search_facet.filters
      mock.verify
    end

    puts "#{File.basename(__FILE__)}: #{self.method_name} complete!"
  end

  # should return facet configuration object with name of facet for UI and filter options of id/name
  test 'should return facet config' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    config = @search_facet.facet_config
    assert_equal 'Species', config[:name]
    assert_equal [{id: 'NCBITaxon_9606', name: 'Homo sapiens'}], config[:filters]

    puts "#{File.basename(__FILE__)}: #{self.method_name} complete!"
  end

  # should correctly generate sub-query string for extracting distinct values from BQ
  test 'should generate correct distinct sub-query' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    sub_query = @search_facet.generate_distinct_sub_query(@search_facet.big_query_id_column)
    assert_equal @search_facet.big_query_id_column, sub_query

    array_based_facet = SearchFacet.new(
        name: 'Disease',
        filters: [
            {id: 'MONDO_0006052', name: 'pulmonary tuberculosis'}
        ],
        is_ontology_based: true,
        is_array_based: true,
        big_query_id_column: 'disease',
        big_query_name_column: 'disease__ontology_label',
        convention_name: 'alexandria_convention',
        convention_version: '1.1.3'
    )

    array_sub_query = array_based_facet.generate_distinct_sub_query(array_based_facet.big_query_id_column)
    expected_sub_query = "(SELECT * FROM UNNEST(#{array_based_facet.big_query_id_column}))"
    assert_equal expected_sub_query, array_sub_query

    puts "#{File.basename(__FILE__)}: #{self.method_name} complete!"
  end
end
