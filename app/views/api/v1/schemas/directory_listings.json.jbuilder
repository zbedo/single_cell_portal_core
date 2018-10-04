json.fields do
  json.array! DirectoryListing.attribute_names do |attribute|
    json.name attribute
    if DirectoryListing.fields[attribute].options[:type].to_s =~ /Object/
      json.type 'BSON::ObjectId'
    else
      json.type DirectoryListing.fields[attribute].options[:type].to_s
      if DirectoryListing.fields[attribute].default_val.to_s.present?
        json.default_value DirectoryListing.fields[attribute].default_val
      end
    end
    if DirectoryListing::REQUIRED_ATTRIBUTES.include? attribute
      json.required true
    end
    if attribute == 'files'
      json.values DirectoryListing::FILE_ARRAY_ATTRIBUTES
    end
  end
end
json.required_fields DirectoryListing::REQUIRED_ATTRIBUTES