json.set! :name, study_file.name
json.set! :file_type, study_file.file_type
json.set! :description, study_file.description
json.set! :bucket_location, study_file.bucket_location
json.set! :upload_file_size, study_file.upload_file_size
json.set! :download_url, api_v1_site_study_download_data_url(accession: study_file.study.accession, filename: study_file.bucket_location)
if study_file.is_bundle_parent?
  json.bundled_files do
    json.array! study_file.bundled_files, partial: 'api/v1/search/study_file', as: :study_file, locals: {study: study_file.study}
  end
end