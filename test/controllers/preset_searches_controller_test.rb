require "test_helper"

describe PresetSearchesController do
  let(:stored_search) { stored_searches :one }

  it "gets index" do
    get stored_searches_url
    value(response).must_be :success?
  end

  it "gets new" do
    get new_stored_search_url
    value(response).must_be :success?
  end

  it "creates stored_search" do
    expect {
      post stored_searches_url, params: { stored_search: { accession_whitelist: stored_search.accession_whitelist, facet_filters: stored_search.facet_filters, identifier: stored_search.identifier, name: stored_search.name, public: stored_search.public, search_terms: stored_search.search_terms } }
    }.must_change "StoredSearch.count"

    must_redirect_to stored_search_path(PresetSearch.last)
  end

  it "shows stored_search" do
    get stored_search_url(stored_search)
    value(response).must_be :success?
  end

  it "gets edit" do
    get edit_stored_search_url(stored_search)
    value(response).must_be :success?
  end

  it "updates stored_search" do
    patch stored_search_url(stored_search), params: { stored_search: { accession_whitelist: stored_search.accession_whitelist, facet_filters: stored_search.facet_filters, identifier: stored_search.identifier, name: stored_search.name, public: stored_search.public, search_terms: stored_search.search_terms } }
    must_redirect_to stored_search_path(stored_search)
  end

  it "destroys stored_search" do
    expect {
      delete stored_search_url(stored_search)
    }.must_change "StoredSearch.count", -1

    must_redirect_to stored_searches_path
  end
end
