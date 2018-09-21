study.attributes.each do |name, value|
  unless name == '_id' && !study.persisted?
    json.set! name, value
  end
end