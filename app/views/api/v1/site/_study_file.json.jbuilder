json.set! :name, study_file.name
json.set! :file_type, study_file.file_type
json.set! :description, study_file.description
json.set! :upload_file_name, study_file.upload_file_name
json.set! :upload_file_size, study_file.upload_file_size
json.set! :download_url, api_v1_site_download_data_url(accession: study.accession, filename: study_file.upload_file_name)
json.set! :media_url, api_v1_site_stream_data_url(accession: study.accession, filename: study_file.upload_file_name)