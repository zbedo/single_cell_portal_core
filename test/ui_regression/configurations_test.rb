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
    @driver.manage.timeouts.implicit_wait = 15
		@base_url = $portal_url
		@accept_next_alert = true
		@wait = Selenium::WebDriver::Wait.new(:timeout => 30)
		@base_path = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))

		puts "\n"
  end

  # called on completion of every test (whether it passes or fails)
  def teardown
    @driver.quit
  end

  # test the various levels of firecloud access integration (on, read-only, local-off, and off)
	test 'admin: configurations: firecloud access' do
		puts "#{File.basename(__FILE__)}: Test method: #{self.method_name}"
		path = @base_url + '/admin'
		@driver.get path
		close_modal(@driver, 'message_modal')
		login(@driver, $test_email, $test_email_password)

		# show the 'panic' modal and disable downloads
		panic_modal_link = @driver.find_element(:id, 'show-panic-modal')
		panic_modal_link.click
		wait_for_render(@driver, :id, 'panic-modal')
		disable_button = @driver.find_element(:id, 'disable-firecloud-access')
		disable_button.click
		close_modal(@driver, 'message_modal')

		# assert access is revoked
		firecloud_url = "https://portal.firecloud.org/#workspaces/single-cell-portal/#{$env}-test-study-#{$random_seed}"
		@driver.get firecloud_url
		assert !element_present?(@driver, :class, 'fa-check-circle'), 'did not revoke access - study workspace still loads'

		# test that study admin access is disabled
		# go to homepage first to set referrer
		@driver.get @base_url
		studies_path = @base_url + '/studies'
		@driver.get studies_path
		assert element_present?(@driver, :id, 'message_modal'), 'did not show alert'
		assert @driver.current_url == @base_url, 'did not redirect to home page'

		# set access to readonly
		@driver.get path
		panic_modal_link = @driver.find_element(:id, 'show-panic-modal')
		panic_modal_link.click
		wait_for_render(@driver, :id, 'panic-modal')
		compute_button = @driver.find_element(:id, 'disable-compute-access')
		compute_button.click
		close_modal(@driver, 'message_modal')

		# assert access is revoked
		@driver.get firecloud_url
		assert !element_present?(@driver, :class, 'fa-trash'), 'did not revoke compute access - study workspace can still be deleted'

		# test that study admin access is disabled
		# go to homepage first to set referrer
		@driver.get @base_url
		studies_path = @base_url + '/studies'
		@driver.get studies_path
		assert element_present?(@driver, :id, 'message_modal'), 'did not show alert'
		assert @driver.current_url == @base_url, 'did not redirect to home page'

		# now restore access
		@driver.get path
		panic_modal_link = @driver.find_element(:id, 'show-panic-modal')
		panic_modal_link.click
		wait_for_render(@driver, :id, 'panic-modal')
		disable_button = @driver.find_element(:id, 'enable-firecloud-access')
		disable_button.click
		close_modal(@driver, 'message_modal')

		# assert access is restored, wait a few seconds for changes to propogate
		sleep(3)
		@driver.get firecloud_url
		assert element_present?(@driver, :class, 'fa-check-circle'), 'did not restore access - study workspace does not load'

		# assert study access is restored
		@driver.get studies_path
		assert element_present?(@driver, :id, 'studies'), 'did not find studies table'
		assert @driver.current_url == studies_path, 'did not load studies path correctly'

		# finally, check local-only option to block downloads and study access in the portal only
		@driver.get path
		panic_modal_link = @driver.find_element(:id, 'show-panic-modal')
		panic_modal_link.click
		wait_for_render(@driver, :id, 'panic-modal')
		local_access_button = @driver.find_element(:id, 'disable-local-access')
		local_access_button.click
		close_modal(@driver, 'message_modal')

		# assert firecloud projects are still accessible, but studies and downloads are not
		@driver.get firecloud_url
		assert element_present?(@driver, :class, 'fa-check-circle'), 'did maintain restore access - study workspace does not load'
		test_study_path = @base_url + "/study/test-study-#{$random_seed}"
		@driver.get(test_study_path)
		wait_until_page_loads(@driver, test_study_path)
		open_ui_tab(@driver, 'study-download')
		disabled_downloads = @driver.find_elements(:class, 'disabled-download')
		assert disabled_downloads.size > 0, 'did not disable downloads, found 0 disabled-download links'
		@driver.get studies_path
		assert element_present?(@driver, :id, 'message_modal'), 'did not show alert'
		assert @driver.current_url == @base_url, 'did not redirect to home page'

		# cleanup by restoring access
		@driver.get path
		panic_modal_link = @driver.find_element(:id, 'show-panic-modal')
		panic_modal_link.click
		wait_for_render(@driver, :id, 'panic-modal')
		disable_button = @driver.find_element(:id, 'enable-firecloud-access')
		disable_button.click
		close_modal(@driver, 'message_modal')

		puts "#{File.basename(__FILE__)}: Test method: #{self.method_name} successful!"
	end

	test 'admin: configurations: download-quota: enforcement' do
		puts "#{File.basename(__FILE__)}: Test method: #{self.method_name}"
		path = @base_url + '/admin'
		@driver.get path
		close_modal(@driver, 'message_modal')
		login(@driver, $test_email, $test_email_password)

		# find quota object or create if needed
		if element_present?(@driver, :class, 'daily-user-download-quota-edit')
			quota_edit = @driver.find_element(:class, 'daily-user-download-quota-edit')
			quota_edit.click
			multiplier = @driver.find_element(:id, 'admin_configuration_multiplier')
			multiplier.send_key('byte')
			save = @driver.find_element(:id, 'save-configuration')
			save.click
			wait_until_page_loads(@driver, path)
			close_modal(@driver, 'message_modal')
		else
			create = @driver.find_element(id: 'create-new-configuration')
			create.click
			value = @driver.find_element(:id, 'admin_configuration_value')
			value.send_key(2)
			multiplier = @driver.find_element(:id, 'admin_configuration_multiplier')
			multiplier.send_key('byte')
			save = @driver.find_element(:id, 'save-configuration')
			save.click
			wait_until_page_loads(@driver, path)
			close_modal(@driver, 'message_modal')
		end

		# now test downloads
		study_path = @base_url + "/study/test-study-#{$random_seed}"
		@driver.get(study_path)
		wait_until_page_loads(@driver, study_path)

		open_ui_tab(@driver, 'study-download')

		files = @driver.find_elements(:class, 'disabled-download')
		assert files.size >= 1, 'downloads not properly disabled (did not find any disabled-download links)'

		# try bypassing download with a direct call to file we uploaded earlier
		direct_link = @base_url + "/data/public/test-study-#{$random_seed}/expression_matrix_example.txt"
		@driver.get direct_link
		alert_content = @driver.find_element(:id, 'alert-content')
		assert alert_content.text == 'You have exceeded your current daily download quota. You must wait until tomorrow to download this file.', 'download was not successfully blocked'

		# reset quota back to default, we don't need to test downloads again because that gets done in front-end: download study data file
		@driver.get path
		quota_edit = @driver.find_element(:class, 'daily-user-download-quota-edit')
		quota_edit.click
		multiplier = @driver.find_element(:id, 'admin_configuration_multiplier')
		multiplier.send_key('terabyte')
		save = @driver.find_element(:id, 'save-configuration')
		save.click
		wait_until_page_loads(@driver, path)
		close_modal(@driver, 'message_modal')

		puts "#{File.basename(__FILE__)}: Test method: #{self.method_name} successful!"
	end

	# test unlocking jobs feature - this mainly just tests that the request goes through. it is difficult to test the
	# entire method as it require the portal to crash while in the middle of a parse, which cannot be reliably automated.

	test 'admin: configurations: restart locked jobs' do
		puts "#{File.basename(__FILE__)}: Test method: #{self.method_name}"
		path = @base_url + '/users/sign_in'
		@driver.get path
		login(@driver, $test_email, $test_email_password)
		@driver.get @base_url + '/admin'

		actions_dropdown = @driver.find_element(:id, 'admin_action')
		actions_dropdown.send_keys 'Unlock Orphaned Jobs'
		execute_button = @driver.find_element(:id, 'perform-admin-task')
		execute_button.click
		wait_for_render(@driver, :id, 'message_modal')
		assert element_visible?(@driver, :id, 'message_modal'), 'confirmation message did not appear'
		message = @driver.find_element(:id, 'notice-content').text
		assert message.include?('jobs'), "'confirmation message did not pertain to locked jobs ('jobs' not found)"

		puts "#{File.basename(__FILE__)}: Test method: #{self.method_name} successful!"
	end

	# reset user download quotas to 0 bytes
	test 'admin: configurations: download-quota: reset' do
		puts "#{File.basename(__FILE__)}: Test method: #{self.method_name}"
		path = @base_url + '/users/sign_in'
		@driver.get path
		login(@driver, $test_email, $test_email_password)
		@driver.get @base_url + '/admin'

		actions_dropdown = @driver.find_element(:id, 'admin_action')
		actions_dropdown.send_keys 'Reset User Download Quotas'
		execute_button = @driver.find_element(:id, 'perform-admin-task')
		execute_button.click
		wait_for_render(@driver, :id, 'message_modal')
		assert element_visible?(@driver, :id, 'message_modal'), 'confirmation message did not appear'
		message = @driver.find_element(:id, 'notice-content').text
		expected_conf = 'All user download quotas successfully reset to 0.'
		assert message == expected_conf, "correct confirmation did not appear, expected #{expected_conf} but found #{message}"

		puts "#{File.basename(__FILE__)}: Test method: #{self.method_name} successful!"
	end

	# test force-refreshing the FireCloud API access tokens and storage driver connections
	test 'admin: configurations: refresh api connections' do
		puts "#{File.basename(__FILE__)}: Test method: #{self.method_name}"
		path = @base_url + '/admin'
		@driver.get path
		close_modal(@driver, 'message_modal')
		login(@driver, $test_email, $test_email_password)

		actions_dropdown = @driver.find_element(:id, 'admin_action')
		actions_dropdown.send_keys 'Refresh API Clients'
		execute_button = @driver.find_element(:id, 'perform-admin-task')
		execute_button.click
		wait_for_render(@driver, :id, 'message_modal')
		assert element_visible?(@driver, :id, 'message_modal'), 'confirmation message did not appear'
		message = @driver.find_element(:id, 'notice-content').text
		expected_conf = 'API Client successfully refreshed.'
		assert message.start_with?(expected_conf), "correct confirmation did not appear, expected #{expected_conf} but found #{message}"

		puts "#{File.basename(__FILE__)}: Test method: #{self.method_name} successful!"
  end

  # update a user's roles (admin or reporter)
  test 'admin: configurations: update user roles' do
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name}"
    path = @base_url + '/admin'
    @driver.get path
    close_modal(@driver, 'message_modal')
    login(@driver, $test_email, $test_email_password)

    open_ui_tab(@driver, 'users')
    share_email_id = $share_email.gsub(/[@.]/, '-')
    share_user_edit = @driver.find_element(:id, share_email_id + '-edit')
    share_user_edit.click
    wait_until_page_loads(@driver, 'edit user page')
    user_reporter = @driver.find_element(:id, 'user_reporter')
    user_reporter.send_keys('Yes')
    save_btn = @driver.find_element(:id, 'save-user')
    save_btn.click

    # assert that reporter access was granted
    close_modal(@driver, 'message_modal')
    open_ui_tab(@driver, 'users')
    assert element_present?(@driver, :id, share_email_id + '-reporter'), "did not grant reporter access to #{$share_email}"

    # now remove to reset for future tests
    share_user_edit = @driver.find_element(:id, share_email_id + '-edit')
    share_user_edit.click
    wait_until_page_loads(@driver, 'edit user page')
    user_reporter = @driver.find_element(:id, 'user_reporter')
    user_reporter.send_keys('No')
    save_btn = @driver.find_element(:id, 'save-user')
    save_btn.click

    # assert that reporter access was removed
    close_modal(@driver, 'message_modal')
    open_ui_tab(@driver, 'users')
    share_roles = @driver.find_element(:id, share_email_id + '-roles')
    assert share_roles.text == '', "did not remove reporter access from #{$share_email}"

    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name} successful!"
  end

  # test whether or not maintenance mode functions properly
  test 'front-end: maintenance mode' do
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name}"
    # only execute this test when testing locally - when using a remote host it will fail as the shell script being executed
    # is on the wrong host
    omit_if !$portal_url.include?('localhost'), 'cannot enable maintenance mode on remote host' do
      # enable maintenance mode
      system("#{@base_path}/bin/enable_maintenance.sh on")
      @driver.get @base_url
      assert element_present?(@driver, :id, 'maintenance-notice'), 'could not load maintenance page'
      # disable maintenance mode
      system("#{@base_path}/bin/enable_maintenance.sh off")
      @driver.get @base_url
      assert element_present?(@driver, :id, 'main-banner'), 'could not load home page'
      puts "#{File.basename(__FILE__)}: Test method: #{self.method_name} successful!"
    end
  end
end