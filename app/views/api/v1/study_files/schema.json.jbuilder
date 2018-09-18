json.study_file_attributes StudyFile.attribute_names.each do |attribute|
  if attribute == 'created_at' || attribute == 'updated_at'
    next
  elsif attribute == 'study_id'
    json.study_id params[:study_id]
  elsif attribute == 'file_type'
    json.file_type StudyFile::STUDY_FILE_TYPES
  else
    json.set! attribute, StudyFile.fields[attribute].options[:type].to_s
  end
end