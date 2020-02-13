class AddInitialFacets < Mongoid::Migration
  def self.up
    SearchFacet.find_or_create_by!(name: "species") do |facet|
      facet.identifier = "species"
      facet.is_ontology_based = true
      facet.is_array_based = false
      facet.big_query_id_column = 'species'
      facet.big_query_name_column = 'species__ontology_label'
      facet.convention_name = 'alexandria'
      facet.convention_version = '1.0'
      facet.ontology_urls = [{name: 'todo', url: 'https://to.do/ontology'}]
    end
    SearchFacet.find_or_create_by!(name: "sex") do |facet|
      facet.identifier = "sex"
      facet.is_ontology_based = false
      facet.is_array_based = false
      facet.big_query_id_column = 'sex'
      facet.big_query_name_column = 'sex'
      facet.convention_name = 'alexandria'
      facet.convention_version = '1.0'
      facet.ontology_urls = [{name: 'todo', url: 'https://to.do/ontology'}]
    end

    SearchFacet.find_or_create_by!(name: "organ") do |facet|
      facet.identifier = "organ"
      facet.is_ontology_based = true
      facet.is_array_based = false
      facet.big_query_id_column = 'organ'
      facet.big_query_name_column = 'organ__ontology_label'
      facet.convention_name = 'alexandria'
      facet.convention_version = '1.0'
      facet.ontology_urls = [{name: 'todo', url: 'https://to.do/ontology'}]
    end

    SearchFacet.find_or_create_by!(name: "disease") do |facet|
      facet.identifier = "disease"
      facet.is_ontology_based = true
      facet.is_array_based = false
      facet.big_query_id_column = 'disease'
      facet.big_query_name_column = 'disease__ontology_label'
      facet.convention_name = 'alexandria'
      facet.convention_version = '1.0'
      facet.ontology_urls = [{name: 'todo', url: 'https://to.do/ontology'}]
    end

    SearchFacet.find_or_create_by!(name: "protocol") do |facet|
      facet.identifier = "lib_prep_protocol"
      facet.is_ontology_based = true
      facet.is_array_based = false
      facet.big_query_id_column = 'library_preparation_protocol'
      facet.big_query_name_column = 'library_preparation_protocol__ontology_label'
      facet.convention_name = 'alexandria'
      facet.convention_version = '1.0'
      facet.ontology_urls = [{name: 'todo', url: 'https://to.do/ontology'}]
    end
  end

  def self.down
    SearchFacet.destroy_all
  end
end
