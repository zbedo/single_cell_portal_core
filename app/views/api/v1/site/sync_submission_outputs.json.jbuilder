json.submission_outputs do
  json.array! @unsynced_files, partial: 'api/v1/study_files/study_file_sync', as: :study_file
end