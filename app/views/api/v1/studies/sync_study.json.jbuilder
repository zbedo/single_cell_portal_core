json.study_shares @study.study_shares.to_a, partial: 'api/v1/study_shares/study_share', as: :study_share
json.study_files do
  json.unsynced @unsynced_files, partial: 'api/v1/study_files/study_file_sync', as: :study_file
  json.orphaned @orphaned_study_files, partial: 'api/v1/study_files/study_file_sync', as: :study_file
  json.synced @synced_study_files, partial: 'api/v1/study_files/study_file_sync', as: :study_file
end
json.directory_listings do
  json.unsynced @unsynced_directories, partial: 'api/v1/directory_listings/directory_listing', as: :directory_listing
  json.synced @synced_directories, partial: 'api/v1/directory_listings/directory_listing', as: :directory_listing
end