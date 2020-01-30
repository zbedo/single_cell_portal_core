json.set! :type, params[:type]
json.set! :terms, params[:terms]
json.set! :facets, params[:facets]
json.studies do
  json.array! @studies, partial: 'api/v1/site/study', as: :study
end
