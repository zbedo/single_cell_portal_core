json.set! :type, params[:type]
json.set! :terms, params[:terms]
json.set! :current_page, @results.current_page.to_i
json.set! :total_studies, @results.total_entries
json.set! :total_pages, @results.total_pages
if @selected_branding_group.present?
  json.set! :scpbr, @selected_branding_group.name_as_id
end
json.facets do
  json.array! @facets do |facet|
    json.set! :id, facet[:id]
    json.set! :filters, facet[:filters]
  end
end
json.studies do
  json.array! @results, partial: 'api/v1/search/study', as: :study
end
