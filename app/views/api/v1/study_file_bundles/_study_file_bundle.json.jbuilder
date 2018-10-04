study_file_bundle.attributes.each do |name, value|
  unless name == '_id' && !study_file_bundle.persisted?
    json.set! name, value
  end
end
json.set! :study_files do
  json.array! study_file_bundle.study_files.to_a, partial: 'api/v1/study_files/study_file', as: :study_file
end