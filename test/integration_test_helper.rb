ENV["RAILS_ENV"] = "test"
require File.expand_path("../../config/environment", __FILE__)
require "rails/test_help"

# upload a file from the test_data directory to a study
def perform_study_file_upload(filename, study_file_params, study_id)
  file_upload = Rack::Test::UploadedFile.new(Rails.root.join('test', 'test_data', filename))
  study_file_params[:study_file].merge!(upload: file_upload)
  patch "/single_cell/studies/#{study_id}/upload", params: study_file_params, headers: {'Content-Type' => 'multipart/form-data'}
end

# start parsing a file from the test_data directory to a study
def initiate_study_file_parse(filename, study_id)
  study_file_params = {file: filename}
  post "/single_cell/studies/#{study_id}/parse", params: study_file_params, headers: {'Content-Type' => 'multipart/form-data'}, xhr: true
end

# configure omniauth response for a given user
def auth_as_user(user)
  OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
                                                                         :provider => 'google_oauth2',
                                                                         :uid => user.uid,
                                                                         :email => user.email
                                                                     })
end

def get_bq_row_count(bq_dataset, study)
  bq_dataset.query("SELECT COUNT(*) count FROM #{CellMetadatum::BIGQUERY_TABLE} WHERE study_accession = '#{study.accession}'", cache: false)[0][:count]
end
