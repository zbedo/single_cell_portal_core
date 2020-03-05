json.set! :name, search_facet_config.name
if search_facet_config.is_array_based?
  json.set! :type, :array
  json.items do
    json.set! :type, search_facet_config.data_type
  end
else
  json.set! :type, search_facet_config.data_type
end
json.set! :id, search_facet_config.identifier
json.set! :links, search_facet_config.ontology_urls
json.set! :filters, search_facet_config.filters
if search_facet_config.is_numeric?
  json.set! :unit, search_facet_config.unit
  json.set! :max, search_facet_config.max
  json.set! :min, search_facet_config.min
  json.set! :all_units, SearchFacet::TIME_UNITS
end
