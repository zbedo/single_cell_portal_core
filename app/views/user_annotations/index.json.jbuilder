json.array!(@user_annotations) do |user_annotation|
  json.extract! user_annotation, :id
  json.url user_annotation_url(user_annotation, format: :json)
end
