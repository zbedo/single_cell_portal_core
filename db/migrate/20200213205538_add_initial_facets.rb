class AddInitialFacets < Mongoid::Migration
  def self.up
    SearchFacetPopulator.populate_sample_facets
  end

  def self.down
    SearchFacet.destroy_all
  end
end
