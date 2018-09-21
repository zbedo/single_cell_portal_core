study_share.attributes.each do |name, value|
  unless name == '_id' && !study_share.persisted?
    json.set! name, value
  end
end