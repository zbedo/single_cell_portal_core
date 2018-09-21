study_file.attributes.each do |name, value|
  unless name == '_id' && !study_file.persisted?
    json.set! name, value
  end
end
