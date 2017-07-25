#!/usr/bin/env bash

echo "Seeding test database..."
rake RAILS_ENV=test db:seed
echo "Database initialized, launching unit & integration tests..."
ruby -I test test/integration/cache_management_test.rb
ruby -I test test/models/cluster_group_test.rb
ruby -I test test/models/user_annotation_test.rb
echo "Cleaning up..."
/home/app/webapp/bin/rails runner -e test "Study.destroy_all"
/home/app/webapp/bin/rails runner -e test "User.destroy_all"
echo "Cleanup complete!"
exit