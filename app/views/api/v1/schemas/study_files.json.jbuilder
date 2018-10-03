json.fields do
  json.array! StudyFile.attribute_names do |attribute|
    unless attribute == '_id'
      json.name attribute
      if StudyFile.fields[attribute].options[:type].to_s =~ /Object/
        json.type 'BSON::ObjectId'
        if attribute == 'taxon_id'
          json.values Taxon.all.map {|taxon| {id: taxon.id.to_s, common_name: taxon.common_name}}
          json.set! 'required_if', {file_type: StudyFile::TAXON_REQUIRED_TYPES}
        elsif attribute == 'genome_assembly_id'
          json.values GenomeAssembly.all.map {|assembly| {id: assembly.id.to_s, name: assembly.name}}
          json.set! 'required_if', {file_type: StudyFile::ASSEMBLY_REQUIRED_TYPES}
        end
      else
        json.type StudyFile.fields[attribute].options[:type].to_s
        if StudyFile.fields[attribute].default_val.to_s.present?
          json.default_value StudyFile.fields[attribute].default_val
        end
        # special cases for requirements
        if attribute =~ /upload_file/ || attribute =~ /upload_content/
          json.set! 'required_if', {human_data: false}
        end
        if attribute == 'human_fastq_url'
          json.set! 'required_if', {human_data: true}
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
end
json.required_fields StudyFile::REQUIRED_ATTRIBUTES