json.extract! preset_search, :id, :name, :identifier, :accession_whitelist, :search_terms, :facet_filters, :public, :created_at, :updated_at
json.url preset_search_url(stored_search, format: :json)
