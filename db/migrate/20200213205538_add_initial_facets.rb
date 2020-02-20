class AddInitialFacets < Mongoid::Migration
  def self.up
    FacetPopulator.populate_sample_facets
  end

  def self.down
    SearchFacet.destroy_all
  end
end
