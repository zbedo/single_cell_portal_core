directory_listing.attributes.each do |name, value|
  unless name == '_id' && !directory_listing.persisted?
    json.set! name, value
  end
end