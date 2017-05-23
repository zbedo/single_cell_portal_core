#!/usr/bin/env bash

echo "Seeding test database..."
rake RAILS_ENV=test db:seed
echo "Database initialized, launching unit & integration tests..."
rake RAILS_ENV=test test
echo "Cleaning up..."
/home/app/webapp/bin/rails runner -e test "Study.destroy_all"
echo "Cleanup complete!"
exit