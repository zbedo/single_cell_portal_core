#!/usr/bin/env bash

# script that is called when booting portal in test environment to run all unit tests in the correct order

start=$(date +%s)
echo "Seeding test database..."
rake RAILS_ENV=test db:seed
echo "Database initialized, launching unit & integration tests..."
ruby -I test test/integration/fire_cloud_client_test.rb
ruby -I test test/integration/cache_management_test.rb
ruby -I test test/api/studies_controller_test.rb
ruby -I test test/api/study_files_controller_test.rb
ruby -I test test/api/study_shares_controller_test.rb
ruby -I test test/api/directory_listings_controller_test.rb
ruby -I test test/models/cluster_group_test.rb
ruby -I test test/models/user_annotation_test.rb
ruby -I test test/models/parse_utils_test.rb
echo "Cleaning up..."
/home/app/webapp/bin/rails runner -e test "DataArray.delete_all"
/home/app/webapp/bin/rails runner -e test "Study.destroy_all"
/home/app/webapp/bin/rails runner -e test "User.destroy_all"
/home/app/webapp/bin/rails runner -e test "Delayed::Job.destroy_all"
echo "Cleanup complete!"
end=$(date +%s)
difference=$(($end - $start))
min=$(($difference / 60))
sec=$(($difference % 60))
echo "Total elapsed time: $min minutes, $sec seconds"
exit