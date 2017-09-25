require 'rubygems'
require 'test/unit'
require 'selenium-webdriver'
require File.expand_path('ui_test_helper.rb', 'test')

# parse arguments from parent script
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

## Print pid so user can kill tests if need be
puts "#{File.basename(__FILE__)} running in process #{Process.pid}"

class UiTestSuite < Test::Unit::TestCase
  self.test_order = $order

  # setup is called before every test is run, this instantiates the driver and configures waits and other variables needed
  def setup
    # disable the 'save your password' prompt
    caps = Selenium::WebDriver::Remote::Capabilities.chrome("chromeOptions" => {'prefs' => {'credentials_enable_service' => false}})
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('--enable-webgl-draft-extensions')
    if $headless == 'true'
      options.add_argument('headless')
    end

    @driver = Selenium::WebDriver::Driver.for :chrome, driver_path: $chromedriver_dir, options: options, desired_capabilities: caps
    @driver.manage.window.maximize
    @base_url = $portal_url
    @accept_next_alert = true
    @driver.manage.timeouts.implicit_wait = 15
    puts "\n"
  end

  # called on completion of every test (whether it passes or fails)
  def teardown
    @driver.quit
  end

	##
	## CLEANUP
	##

	# final test, remove test study that was created and used for front-end tests
	# runs last to clean up data for next test run
	test 'cleanup: delete all test studies' do
		puts "Test method: #{self.method_name}"

		# log in first
		path = @base_url + '/studies'
		@driver.get path
		close_modal(@driver, 'message_modal')
		login(@driver, $test_email, $test_email_password)

		# delete test
		@driver.find_element(:class, "test-study-#{$random_seed}-delete").click
		accept_alert(@driver)
		close_modal(@driver, 'message_modal')

		# delete private
		@driver.find_element(:class, "private-study-#{$random_seed}-delete").click
		accept_alert(@driver)
		close_modal(@driver, 'message_modal')

		# delete gzip parse
		@driver.find_element(:class, "gzip-parse-#{$random_seed}-delete").click
		accept_alert(@driver)
		close_modal(@driver, 'message_modal')

		# delete embargo study
		@driver.find_element(:class, "embargo-study-#{$random_seed}-delete").click
		accept_alert(@driver)
		close_modal(@driver, 'message_modal')

		# delete 2d test
		@driver.find_element(:class, "twod-study-#{$random_seed}-delete").click
		accept_alert(@driver)
		wait_for_render(@driver, :id, 'message_modal')
		close_modal(@driver, 'message_modal')

		puts "Test method: #{self.method_name} successful!"
	end
end