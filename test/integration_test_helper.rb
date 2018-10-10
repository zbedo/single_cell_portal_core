ENV["RAILS_ENV"] = "test"
require File.expand_path("../../config/environment", __FILE__)
require "rails/test_help"

def perform_study_file_upload(filename, study_file_params, study_id)
  file_upload = Rack::Test::UploadedFile.new(Rails.root.join('test', 'test_data', filename))
  study_file_params[:study_file].merge!(upload: file_upload)
  patch "/single_cell/studies/#{study_id}/upload", params: study_file_params, headers: {'Content-Type' => 'multipart/form-data'}
end
