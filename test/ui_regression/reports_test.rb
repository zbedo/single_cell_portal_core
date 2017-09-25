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
		@wait = Selenium::WebDriver::Wait.new(:timeout => 30)
		@accept_next_alert = true

    puts "\n"
  end

  # called on completion of every test (whether it passes or fails)
  def teardown
    @driver.quit
  end

  # test loading plots from reporting controller
	test 'admin: reports: view' do
		puts "#{File.basename(__FILE__)}: Test method: #{self.method_name}"

		path = @base_url + '/reports'
		@driver.get(path)
		close_modal(@driver, 'message_modal')
		login(@driver, $test_email, $test_email_password)
		wait_until_page_loads(@driver, path)

		# check for reports
		report_plots = @driver.find_elements(:class, 'plotly-report')
		assert report_plots.size == 8, "did not find correct number of plots, expected 8 but found #{report_plots.size}"
		report_plots.each do |plot|
			rendered = @driver.execute_script("return $('##{plot['id']}').data('rendered')")
			assert rendered, "#{plot['id']} rendered status was not true"
		end

		# test toggle column total button
		toggle_btn = @driver.find_element(:id, 'toggle-column-annots')

		# turn off
		toggle_btn.click
		@wait.until {wait_for_plotly_render(@driver, '#plotly-study-email-domain-dist', 'rendered')}
		new_layout = @driver.execute_script("return document.getElementById('plotly-study-email-domain-dist').layout")
		assert new_layout['annotations'].nil?, "did not turn off annotations, expected nil but found #{new_layout['annotations']}"

		# turn on
		toggle_btn.click
		@wait.until {wait_for_plotly_render(@driver, '#plotly-study-email-domain-dist', 'rendered')}
		layout = @driver.execute_script("return document.getElementById('plotly-study-email-domain-dist').layout")
		assert !layout['annotations'].nil?, "did not turn on annotations, expected annotations array but found #{layout['annotations']}"

		puts "#{File.basename(__FILE__)}: Test method: #{self.method_name} successful!"
	end

	# send a request to site admins for a new report plot
	test 'admin: reports: request new' do
		puts "#{File.basename(__FILE__)}: Test method: #{self.method_name}"

		path = @base_url + '/reports'
		@driver.get(path)
		close_modal(@driver, 'message_modal')
		login(@driver, $test_email, $test_email_password)
		wait_until_page_loads(@driver, path)

		request_modal = @driver.find_element(:id, 'report-request')
		request_modal.click
		wait_for_render(@driver, :id, 'contact-modal')

		@driver.switch_to.frame(@driver.find_element(:tag_name, 'iframe'))
		message = @driver.find_element(:class, 'cke_editable')
		message_content = "This is a report request."
		message.send_keys(message_content)
		@driver.switch_to.default_content
		send_request = @driver.find_element(:id, 'send-report-request')
		send_request.click
		wait_for_render(@driver, :id, 'message_modal')
		assert element_visible?(@driver, :id, 'message_modal'), 'confirmation modal did not show.'
		notice_content = @driver.find_element(:id, 'notice-content')
		confirmation_message = 'Your message has been successfully delivered.'
		assert notice_content.text == confirmation_message, "did not find confirmation message, expected #{confirmation_message} but found #{notice_content.text}"

		puts "#{File.basename(__FILE__)}: Test method: #{self.method_name} successful!"
  end
end