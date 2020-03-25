external_resource.attributes.each do |name, value|
  unless name == '_id' && !external_resource.persisted?
    json.set! name, value
  end
end
