#!/usr/bin/env bash

# script that is called when booting portal in test environment to run all unit tests in the correct order as some
# tests change downstream behavior after they've run

start=$(date +%s)
echo "Seeding test database..."
rake RAILS_ENV=test db:seed
echo "Database initialized, launching unit & integration tests..."
ruby -I test test/integration/fire_cloud_client_test.rb
ruby -I test test/integration/cache_management_test.rb
ruby -I test test/api/studies_controller_test.rb
ruby -I test test/api/study_files_controller_test.rb
ruby -I test test/api/study_file_bundles_controller_test.rb
ruby -I test test/api/study_shares_controller_test.rb
ruby -I test test/api/directory_listings_controller_test.rb
ruby -I test test/models/cluster_group_test.rb
ruby -I test test/models/user_annotation_test.rb
ruby -I test test/models/parse_utils_test.rb
echo "Cleaning up..."
rake RAILS_ENV=test db:purge
echo "Cleanup complete!"
end=$(date +%s)
difference=$(($end - $start))
min=$(($difference / 60))
sec=$(($difference % 60))
echo "Total elapsed time: $min minutes, $sec seconds"
exit