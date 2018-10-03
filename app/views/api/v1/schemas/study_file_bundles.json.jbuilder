json.fields do
  json.array! StudyFileBundle.attribute_names do |attribute|
    json.name attribute
    if StudyFileBundle.fields[attribute].options[:type].to_s =~ /Object/
      json.type 'BSON::ObjectId'
    else
      json.type StudyFileBundle.fields[attribute].options[:type].to_s
      if StudyFileBundle.fields[attribute].default_val.to_s.present?
        json.default_value StudyFileBundle.fields[attribute].default_val
      end
    end
    if StudyFileBundle::REQUIRED_ATTRIBUTES.include? attribute
      json.required true
    end
    if attribute == 'original_file_list'
      json.values StudyFileBundle::FILE_ARRAY_ATTRIBUTES
    end
    if attribute == 'bundle_type'
      json.values StudyFileBundle::BUNDLE_TYPES
    end
  end
end
json.required_fields StudyFileBundle::REQUIRED_ATTRIBUTES