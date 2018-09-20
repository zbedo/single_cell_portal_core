study_file.attributes.each do |name, value|
  json.set! name, value
end
json.study_file_data_upload_url api_v1_study_study_file_path(study_id: params[:study_id], id: study_file.id)
json.study_file_data_upload_http_method 'PATCH'