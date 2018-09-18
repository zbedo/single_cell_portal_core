json.fields do
  json.array! StudyShare.attribute_names do |attribute|
    json.name attribute
    if StudyShare.fields[attribute].options[:type].to_s =~ /Object/
      json.type 'BSON::ObjectId'
    else
      json.type StudyShare.fields[attribute].options[:type].to_s
      if StudyShare.fields[attribute].default_val.to_s.present?
        json.default_value StudyShare.fields[attribute].default_val
      end
    end
    if StudyShare::REQUIRED_ATTRIBUTES.include? attribute
      json.required true
    end
    if attribute == 'permission'
      json.values StudyShare::PERMISSION_TYPES
    end
  end
end
json.required_fields StudyShare::REQUIRED_ATTRIBUTES