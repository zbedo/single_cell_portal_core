# Methods for populating SearchFacets, based on manual config or schema files

class FacetPopulator
  # quick method to get a few key facets into the database.
  # May be removed once we have auto-populate from schema, or it may be useful for testing purposes to keep constant
  def self.populate_sample_facets
    SearchFacet.find_or_create_by!(name: "species") do |facet|
      facet.identifier = "species"
      facet.is_ontology_based = true
      facet.is_array_based = false
      facet.big_query_id_column = 'species'
      facet.big_query_name_column = 'species__ontology_label'
      facet.convention_name = 'alexandria_convention'
      facet.convention_version = '1.1.3'
      facet.ontology_urls = [{name: 'NCBI organismal classification', url: 'https://www.ebi.ac.uk/ols/api/ontologies/ncbitaxon'}]
    end
    SearchFacet.find_or_create_by!(name: "sex") do |facet|
      facet.identifier = "sex"
      facet.is_ontology_based = false
      facet.is_array_based = false
      facet.big_query_id_column = 'sex'
      facet.big_query_name_column = 'sex'
      facet.convention_name = 'alexandria_convention'
      facet.convention_version = '1.1.3'
    end

    SearchFacet.find_or_create_by!(name: "organ") do |facet|
      facet.identifier = "organ"
      facet.is_ontology_based = true
      facet.is_array_based = false
      facet.big_query_id_column = 'organ'
      facet.big_query_name_column = 'organ__ontology_label'
      facet.convention_name = 'alexandria_convention'
      facet.convention_version = '1.1.3'
      facet.ontology_urls = [{name: 'Uber-anatomy ontology', url: 'https://www.ebi.ac.uk/ols/api/ontologies/uberon'}]
    end

    SearchFacet.find_or_create_by!(name: "disease") do |facet|
      facet.identifier = "disease"
      facet.is_ontology_based = true
      facet.is_array_based = true
      facet.big_query_id_column = 'disease'
      facet.big_query_name_column = 'disease__ontology_label'
      facet.convention_name = 'alexandria_convention'
      facet.convention_version = '1.1.3'
      facet.ontology_urls = [{name: 'MONDO: Monarch Disease Ontology', url: 'https://www.ebi.ac.uk/ols/api/ontologies/mondo'}]
    end

    SearchFacet.find_or_create_by!(name: "library_preparation_protocol") do |facet|
      facet.identifier = "library_preparation_protocol"
      facet.is_ontology_based = true
      facet.is_array_based = false
      facet.big_query_id_column = 'library_preparation_protocol'
      facet.big_query_name_column = 'library_preparation_protocol__ontology_label'
      facet.convention_name = 'alexandria_convention'
      facet.convention_version = '1.1.3'
      facet.ontology_urls = [{name: 'Experimental Factor Ontology', url: 'https://www.ebi.ac.uk/ols/api/ontologies/efo'}]
    end
  end
end
