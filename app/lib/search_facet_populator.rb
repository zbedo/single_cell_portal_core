# Methods for populating SearchFacets, based on manual config or schema files

class SearchFacetPopulator

  EXCLUDED_BQ_COLUMNS = %w(CellID donor_id biosample_id)
  # loads the alexandria convention schema and populates search facets from it
  def self.populate_from_schema
    schema_object = fetch_json_from_url(alexandria_convention_config[:url])
    required_fields = schema_object['required']
    required_fields.each do |field_name|
      if !EXCLUDED_BQ_COLUMNS.include?(field_name) && !field_name.include?('__ontology_label')
        populate_facet_by_name(field_name, schema_object)
      end
    end
  end

  # creates/updates a facet from a name, and returns the new SearchFacet.
  # To manually populate a new Alexandria convention facet from the rails console, run e.g.
  # SearchFacetPopulator.populate_facet_by_name('vaccination__route', SearchFacetPopulator.fetch_alexandria_convention_schema)
  def self.populate_facet_by_name(facet_name, schema_object)
    field_def = schema_object['properties'][facet_name]
    if !field_def
      throw "Unrecognized field name '#{facet_name}' -- could not find definition in schema"
    end
    is_ontology_based = field_def['ontology'].present?
    ontology_label_field_name = facet_name + '__ontology_label'

    updated_facet = SearchFacet.find_or_initialize_by(name: facet_name)
    updated_facet.identifier = facet_name
    updated_facet.data_type = field_def['type'] == 'array' ? field_def['items']['type'] : field_def['type']
    updated_facet.is_ontology_based = is_ontology_based
    updated_facet.is_array_based = 'array'.casecmp(field_def['type']) == 0
    updated_facet.big_query_id_column = facet_name
    updated_facet.big_query_name_column = is_ontology_based ? ontology_label_field_name : facet_name
    updated_facet.convention_name = schema_object['title']
    updated_facet.convention_version = alexandria_convention_config[:version]
    if is_ontology_based
      url = field_def['ontology']
      ontology = fetch_json_from_url(url)
      # check if response has expected keys; if not, default to URL for name value
      ontology_name = ontology.dig('config', 'title') ? ontology['config']['title'] : url
      updated_facet.ontology_urls = [{name: ontology_name, url: url}]
    end
    updated_facet.save!
    updated_facet
  end

  def self.alexandria_convention_config
    {
      url: 'https://storage.googleapis.com/broad-singlecellportal-public/AMC_v1.1.3.json',
      version: '1.1.3' # hardcoded here since the version is not part of the schema file
    }
  end

  # generic fetch of JSON from remote URL, for parsing convention schema or EBI OLS ontology entries
  def self.fetch_json_from_url(url)
    begin
      response = RestClient.get url
      JSON.parse(response.body)
    rescue RestClient::Exception => e
      Rails.logger.error "Unable to fetch JSON from #{url}: #{e.class.name}: #{e.message}"
    rescue JSON::ParserError => e
      Rails.logger.error "Unable to parse response from #{url}: #{e.class.name}: #{e.message}"
    end
  end

  # quick method to get a few key facets into the database.
  # May be removed once we have auto-populate from schema, or it may be useful for testing purposes to keep constant
  def self.populate_sample_facets
    SearchFacet.find_or_create_by!(name: "species") do |facet|
      facet.identifier = "species"
      facet.is_ontology_based = true
      facet.is_array_based = false
      facet.big_query_id_column = 'species'
      facet.big_query_name_column = 'species__ontology_label'
      facet.convention_name = 'Alexandria Metadata Convention'
      facet.convention_version = '1.1.3'
      facet.ontology_urls = [{name: 'NCBI organismal classification', url: 'https://www.ebi.ac.uk/ols/api/ontologies/ncbitaxon'}]
    end
    SearchFacet.find_or_create_by!(name: "sex") do |facet|
      facet.identifier = "sex"
      facet.is_ontology_based = false
      facet.is_array_based = false
      facet.big_query_id_column = 'sex'
      facet.big_query_name_column = 'sex'
      facet.convention_name = 'Alexandria Metadata Convention'
      facet.convention_version = '1.1.3'
    end

    SearchFacet.find_or_create_by!(name: "organ") do |facet|
      facet.identifier = "organ"
      facet.is_ontology_based = true
      facet.is_array_based = false
      facet.big_query_id_column = 'organ'
      facet.big_query_name_column = 'organ__ontology_label'
      facet.convention_name = 'Alexandria Metadata Convention'
      facet.convention_version = '1.1.3'
      facet.ontology_urls = [{name: 'Uber-anatomy ontology', url: 'https://www.ebi.ac.uk/ols/api/ontologies/uberon'}]
    end

    SearchFacet.find_or_create_by!(name: "disease") do |facet|
      facet.identifier = "disease"
      facet.is_ontology_based = true
      facet.is_array_based = true
      facet.big_query_id_column = 'disease'
      facet.big_query_name_column = 'disease__ontology_label'
      facet.convention_name = 'Alexandria Metadata Convention'
      facet.convention_version = '1.1.3'
      facet.ontology_urls = [{name: 'MONDO: Monarch Disease Ontology', url: 'https://www.ebi.ac.uk/ols/api/ontologies/mondo'}]
    end

    SearchFacet.find_or_create_by!(name: "library_preparation_protocol") do |facet|
      facet.identifier = "library_preparation_protocol"
      facet.is_ontology_based = true
      facet.is_array_based = false
      facet.big_query_id_column = 'library_preparation_protocol'
      facet.big_query_name_column = 'library_preparation_protocol__ontology_label'
      facet.convention_name = 'Alexandria Metadata Convention'
      facet.convention_version = '1.1.3'
      facet.ontology_urls = [{name: 'Experimental Factor Ontology', url: 'https://www.ebi.ac.uk/ols/api/ontologies/efo'}]
    end
  end

end
