#!/usr/bin/env bash

# script that is called when booting portal in test environment to run all unit tests in the correct order as some
# tests change downstream behavior after they've run
#
# can take the following arguments:
#
# -t filepath		Run all tests in the specified file
# -R regex			Run all matching tests in the file specified with -t

while getopts "t:R:" OPTION; do
case $OPTION in
	t)
		TEST_FILEPATH="$OPTARG"
		;;
	R)
	  MATCHING_TESTS="$OPTARG"
	  ;;
  esac
done
start=$(date +%s)
echo "Precompiling assets, yarn and webpacker..."
RAILS_ENV=test NODE_ENV=test bin/bundle exec rake assets:clean
RAILS_ENV=test NODE_ENV=test bin/bundle exec rake assets:precompile
echo "Seeding test database..."
rake RAILS_ENV=test db:seed
echo "Database initialized, generating random test seed..."
RANDOM_SEED=`openssl rand -hex 16`
echo $RANDOM_SEED > /home/app/webapp/.random_seed
echo "Launching tests using seed: $RANDOM_SEED"
if [[ -v TEST_FILEPATH ]]
then
  if [[ -v MATCHING_TESTS ]]
  then
    EXTRA_ARGS="-n $MATCHING_TESTS"
  fi
  echo "Running specified tests: $TEST_FILEPATH $EXTRA_ARGS"
  ruby -I test $TEST_FILEPATH $EXTRA_ARGS
else
  echo "Running all unit & integration tests..."
	ruby -I test test/integration/fire_cloud_client_test.rb
	ruby -I test test/integration/cache_management_test.rb
	ruby -I test test/integration/study_admin_test.rb
	ruby -I test test/api/studies_controller_test.rb
	ruby -I test test/api/study_files_controller_test.rb
	ruby -I test test/api/study_file_bundles_controller_test.rb
	ruby -I test test/api/study_shares_controller_test.rb
	ruby -I test test/api/directory_listings_controller_test.rb
	ruby -I test test/models/cluster_group_test.rb
	ruby -I test test/models/user_annotation_test.rb
	ruby -I test test/models/parse_utils_test.rb
fi
echo "Cleaning up..."
rake RAILS_ENV=test db:purge
echo "Cleanup complete!"
end=$(date +%s)
difference=$(($end - $start))
min=$(($difference / 60))
sec=$(($difference % 60))
echo "Total elapsed time: $min minutes, $sec seconds"
exit