json.set! :type, params[:type]
json.set! :terms, params[:terms]
json.facets do
  json.array! @facets do |facet|
    json.set! :id, facet[:id]
    json.set! :filters, facet[:filters]
  end
end
json.studies do
  json.array! @studies, partial: 'api/v1/site/study', as: :study
end
