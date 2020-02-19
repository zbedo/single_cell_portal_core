class AddSchemaFacets < Mongoid::Migration
  def self.up
    SearchFacet.destroy_all
    SearchFacetPopulator.populate_from_schema
  end
end
