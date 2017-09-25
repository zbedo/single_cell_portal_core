require 'rubygems'
require 'securerandom'

# Wrapper script that launches individual test suites that exercise functionality through simulating user interactions via Webdriver
#
# REQUIREMENTS
#
# Each test suite must be run from outside of Docker (i.e. your host machine) as Docker vms have no concept of browsers/screen output
# Therefore, the following languages/packages must be installed on your host:
#
# 1. RVM (or equivalent Ruby language management system)
# 2. Ruby >= 2.3
# 3. Gems: rubygems, test-unit, selenium-webdriver (see Gemfile.lock for version requirements)
# 4. Google Chrome
# 5. Chromedriver (https://sites.google.com/a/chromium.org/chromedriver/); make sure the verison you install works with your version of chrome
# 6. Register for FireCloud (https://portal.firecloud.org) for both Google accounts (needed for auth & sharing acls)

# USAGE
#
# run_ui_regression_suite.rb takes up to ten arguments:
# 1. path to your Chromedriver binary (passed with -c=)
# 2. test email account (passed with -e=); this must be a valid Google & FireCloud user and also configured as an 'admin' account in the portal
# 3. test email account password (passed with -p) NOTE: you must quote the password to ensure it is passed correctly
# 4. share email account (passed with -s=); this must be a valid Google & FireCloud user
# 5. share email account password (passed with -P) NOTE: you must quote the password to ensure it is passed correctly
# 6. test order (passed with -o=); defaults to defined order (can be alphabetic or random, but random will most likely fail horribly
# 7. download directory (passed with -d=); place where files are downloaded on your OS, defaults to standard OSX location (/Users/`whoami`/Downloads)
# 8. portal url (passed with -u=); url to point tests at, defaults to https://localhost/single_cell
# 9. environment (passed with -E=); Rails environment that the target instance is running in.  Needed for constructing certain URLs
# 10. random seed (passed with -r=); random seed to use when running tests (will be needed if you're running front end tests against previously
# 	 created studies from test suite)
# these must be passed with ruby run_ui_regression_suite.rb -c=[/path/to/chromedriver] -e=[test_email] -p=[test_email_password] \
#                                                         -s=[share_email] -P=[share_email_password] -d=[/path/to/download/dir]
#                                                         -u=[portal_url] -e=[environment] -r=[random_seed]
#
# When running tests from run_ui_regression_suite.rb, you cannot pass -n or --ignore-names to run matching tests.  You must run all available
# tests from this script.  To run only matching sub-tests, call the individual test suites in test/ui_regression.
#
# NOTE: when running this test harness, it tends to perform better on an external monitor.  Webdriver is very sensitive to elements not
# being clickable, and the more screen area available, the better.

## INITIALIZATION

# DEFAULTS
$user = `whoami`.strip
$chromedriver_path = '/usr/local/bin/chromedriver'
$usage = "ruby test/ui_test_suite.rb -- -c=/path/to/chromedriver -e=testing.email@gmail.com -p='testing_email_password' -s=sharing.email@gmail.com -P='sharing_email_password' -o=order -d=/path/to/downloads -u=portal_url -E=environment -r=random_seed"
$test_email = ''
$share_email = ''
$test_email_password = ''
$share_email_password  = ''
$order = 'defined'
$download_dir = "/Users/#{$user}/Downloads"
$portal_url = 'https://localhost/single_cell'
$env = 'development'

# generate a global random seed to use with study name creation to prevent naming conflicts
$random_seed = SecureRandom.uuid

# parse arguments
ARGV.each do |arg|
  if arg =~ /\-c\=/
    $chromedriver_path = arg.gsub(/\-c\=/, "")
  elsif arg =~ /\-e\=/
    $test_email = arg.gsub(/\-e\=/, "")
  elsif arg =~ /\-p\=/
    $test_email_password = arg.gsub(/\-p\=/, "")
  elsif arg =~ /\-s\=/
    $share_email = arg.gsub(/\-s\=/, "")
  elsif arg =~ /\-P\=/
    $share_email_password = arg.gsub(/\-P\=/, "")
  elsif arg =~ /\-o\=/
    $order = arg.gsub(/\-o\=/, "").to_sym
  elsif arg =~ /\-d\=/
    $download_dir = arg.gsub(/\-d\=/, "")
  elsif arg =~ /\-u\=/
    $portal_url = arg.gsub(/\-u\=/, "")
  elsif arg =~ /\-E\=/
    $env = arg.gsub(/\-E\=/, "")
  elsif arg =~ /\-r\=/
    $random_seed = arg.gsub(/\-r\=/, "")
  end
end

# print configuration
puts "Chromedriver Binary: #{$chromedriver_path}"
puts "Testing email: #{$test_email}"
puts "Sharing email: #{$share_email}"
puts "Download directory: #{$download_dir}"
puts "Portal URL: #{$portal_url}"
puts "Environment: #{$env}"
puts "Random Seed: #{$random_seed}"

# make sure download & chromedriver paths exist and portal url is valid, otherwise kill tests before running and print usage
if !File.exists?($chromedriver_path)
  puts "No Chromedriver binary found at #{$chromedriver_path}"
  puts $usage
  exit(1)
elsif !Dir.exists?($download_dir)
  puts "No download directory found at #{$download_dir}"
  puts $usage
  exit(1)
elsif !$portal_url.start_with?('https://') || $portal_url[($portal_url.size - 12)..($portal_url.size - 1)] != '/single_cell'
  puts "Invalid portal url: #{$portal_url}; must begin with https:// and end with /single_cell"
  puts $usage
  exit(1)
end

# grab all available test suites
available_tests = Dir.entries('test/ui_regression').delete_if {|e| e.start_with?('.')}

# remove cleanup test as we don't want thi

# construct argument string to pass to each test suite
arg_string = "-- -c=#{$chromedriver_path} -e=#{$test_email} -p='#{$test_email_password}' -s=#{$share_email} -P='#{$share_email_password}' -o=#{$order} -d=#{$download_dir} -u=#{$portal_url} -E=#{$env} -r=#{$random_seed}"

# note start time
start_time = Time.now

# first run create_studies.rb and configurations_test.rb as these are synchronous and will break downstream tests if not run first
puts 'Running synchronous testst first: create_studies.rb, configurations_test.rb'
system("ruby test/ui_regression/create_studies.rb #{arg_string}")
available_tests.delete('create_studies.rb')
system("ruby test/ui_regression/configurations_test.rb #{arg_string}")
available_tests.delete('configurations_test.rb')

# now that synchronous tests are done, fork each remaining suite into a new process and execute
available_tests.each do |test_suite|
  Process.fork do
    system("ruby test/ui_regression/#{test_suite} #{arg_string}")
  end
end

# wait for all test suites to complete
Process.waitall

# run cleanup script
system("ruby test/ui_regression_cleanup.rb #{arg_string}")

# compute total running time and print completion message
puts 'All UI regression suite tests complete!'
end_time = Time.now
run_time = (end_time - start_time).divmod 60.0
puts "Total elapsed time: #{run_time.first} minutes, #{run_time.last} seconds"