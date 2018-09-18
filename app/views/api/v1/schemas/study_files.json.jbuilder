json.fields do
  json.array! StudyFile.attribute_names do |attribute|
    json.name attribute
    if StudyFile.fields[attribute].options[:type].to_s =~ /Object/
      json.type 'BSON::ObjectId'
    else
      json.type StudyFile.fields[attribute].options[:type].to_s
      if StudyFile.fields[attribute].default_val.to_s.present?
        json.default_value StudyFile.fields[attribute].default_val
      end
    end
    if StudyFile::REQUIRED_ATTRIBUTES.include? attribute
      json.required true
    end
    if %w(file_type parse_status status).include?(attribute)
      case attribute
      when 'file_type'
        json.values StudyFile::STUDY_FILE_TYPES
      when 'status'
        json.values StudyFile::UPLOAD_STATUSES
      when 'parse_status'
        json.values StudyFile::PARSE_STATUSES
      end
    end
  end
end
json.required_fields StudyFile::REQUIRED_ATTRIBUTES