json.fields do
  json.array! Study.attribute_names do |attribute|
    json.name attribute
    if Study.fields[attribute].options[:type].to_s =~ /Object/
      json.type 'BSON::ObjectId'
    else
      json.type Study.fields[attribute].options[:type].to_s
      if Study.fields[attribute].default_val.to_s.present?
        json.default_value Study.fields[attribute].default_val
      end
    end
    if Study::REQUIRED_ATTRIBUTES.include? attribute
      json.required true
    end
  end
end
json.required_fields Study::REQUIRED_ATTRIBUTES