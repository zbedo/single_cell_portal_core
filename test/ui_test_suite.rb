require 'rubygems'
require 'test/unit'
require 'selenium-webdriver'

# Unit Test that is actually a user flow test using the Selenium Webdriver to test dev UI directly
#
# REQUIREMENTS
#
# This test suite must be run from outside of Docker (i.e. your host machine) as Docker vms have no concept of browsers/screen output
# Therefore, the following languages/packages must be installed:
#
# 1. RVM (or equivalent Ruby language management system)
# 2. Ruby >= 2.3
# 3. Gems: rubygems, test-unit, selenium-webdriver
# 4. Google Chrome with at least 2 Google accounts already signed in (referred to as $test_email & $share_email)
# 5. Chromedriver (https://sites.google.com/a/chromium.org/chromedriver/)

# USAGE
#
# ui_test_suite.rb takes two arguments:
# 1. path to your Chrome user profile on your system (passed with -p)
# 2. path to your Chromedriver binary (passed with -c)
# this must be passed with ruby test/ui_test_suite.rb -- -p=[/path/to/profile/dir] -c=[/path/to/chromedriver]
# if you do not use -- before the argument and give the appropriate flag (with =), it is processed as a Test::Unit flag and ignored

## INITIALIZATION

# DEFAULTS
$user = `whoami`.strip
$profile_dir = "/Users/#{$user}/Library/Application Support/Google/Chrome/Default"
$chromedriver_path = '/usr/local/bin/chromedriver'
$usage = 'ruby test/ui_test_suite.rb -- -p=/path/to/profile -c=/path/to/chromedriver -e=testing.email@gmail.com -s=sharing.email@gmail.com'
$test_email = ''
$share_email = ''

# parse arguments
ARGV.each do |arg|
	if arg =~ /\-p\=/
		$profile_dir = arg.gsub(/\-p\=/, "")
	elsif arg =~ /\-c\=/
	 	$chromedriver_path = arg.gsub(/\-c\=/, "")
	elsif arg =~ /\-e\=/
		$test_email = arg.gsub(/\-e\=/, "")
	elsif arg =~ /\-s\=/
		$share_email = arg.gsub(/\-s\=/, "")
	end
end

# print configuration
puts "Loaded Chrome Profile: #{$profile_dir}"
puts "Chromedriver Binary: #{$chromedriver_path}"
puts "Testing email: #{$test_email}"
puts "Sharing email: #{$share_email}"

# make sure profile & chromedriver exist, otherwise kill tests before running and print usage
if !Dir.exists?($profile_dir)
	puts "No Chrome profile found at #{$profile_dir}"
	puts $usage
	exit(1)
elsif !File.exists?($chromedriver_path)
	puts "No Chromedriver binary found at #{$chromedriver_path}"
	puts $usage
	exit(1)
end

class UiTestSuite < Test::Unit::TestCase
	self.test_order = :defined

	def setup
		@driver = Selenium::WebDriver::Driver.for :chrome,
																							driver_path: $chromedriver_dir,
																							switches: ["--user-data-dir=#{$profile_dir}",
																												 '--enable-webgl-draft-extensions']
		@driver.manage.window.maximize
		@base_url = 'https://localhost/single_cell'
		@accept_next_alert = true
		@driver.manage.timeouts.implicit_wait = 30
		# only Google auth

		@genes = %w(Itm2a Sergef Chil5 Fam109a Dhx9 Ssu72 Olfr1018 Fam71e2 Eif2b2)
		@wait = Selenium::WebDriver::Wait.new(:timeout => 30)
		@test_data_path = File.expand_path(File.join(File.dirname(__FILE__), 'test_data')) + '/'
		@base_path = File.expand_path(File.join(File.dirname(__FILE__), '..'))
	end

	def teardown
		@driver.quit
	end

	def element_present?(how, what)
		@driver.find_element(how, what)
		true
	rescue Selenium::WebDriver::Error::NoSuchElementError
		false
	end

	def verify(&blk)
		yield
	rescue Test::Unit::AssertionFailedError => ex
		@verification_errors << ex
	end

	def wait_until_page_loads(path)
		@wait.until { @driver.current_url == path }
	end

	# method to close a bootstrap modal by id
	def close_modal(id)
		modal = @driver.find_element(:id, id)
		dismiss = modal.find_element(:class, 'close')
		dismiss.click
		# this is a hack, but different browsers behave differently so this lets the fade animation clear
		sleep(1)
	end

	# wait until element is rendered and visible
	def wait_for_render(how, what)
		@wait.until {@driver.find_element(how, what).displayed? == true}
	end

	# scroll to bottom of page as needed
	def scroll_to_bottom
		@driver.execute_script('window.scrollBy(0,1000)')
		sleep(1)
	end

	# helper to log into admin portion of site
	# Will also approve terms if not accepted yet, waits for redirect back to site, and closes modal
	def login(email)
		google_auth = @driver.find_element(:id, 'google-auth')
		google_auth.click
		puts 'logging in as ' + email
		account = @driver.find_element(xpath: "//button[@value='#{email}']")
		account.click
		# check to make sure if we need to accept terms
		if @driver.current_url.include?('https://accounts.google.com/o/oauth2/auth')
			puts 'approving access'
			approve = @driver.find_element(:id, 'submit_approve_access')
			@clickable = approve['disabled'].nil?
			while @clickable != true
				sleep(1)
				@clickable = @driver.find_element(:id, 'submit_approve_access')['disabled'].nil?
			end
			approve.click
			puts 'access approved'
		end
		# wait for redirect to finish by checking for footer element
		@not_loaded = true
		while @not_loaded == true
			begin
				# we need to return the result of the script to store its value
				loaded = @driver.execute_script("return elementVisible('.footer')")
				if loaded == true
					@not_loaded = false
				end
				sleep(1)
			rescue Selenium::WebDriver::Error::UnknownError
				sleep(1)
			end
		end
		close_modal('message_modal')
		puts 'login successful'
	end

	# admin backend tests of entire study creation process including negative/error tests
	# uses example data in test directoyr as inputs (based off of https://github.com/broadinstitute/single_cell_portal/tree/master/demo_data)
	# these tests run first to create test studies to use in front-end tests later
	test 'create a study' do
		# log in first
		path = @base_url + '/studies/new'
		@driver.get path
		close_modal('message_modal')
		# log in as user #1
		login($test_email)

		# fill out study form
		study_form = @driver.find_element(:id, 'new_study')
		study_form.find_element(:id, 'study_name').send_keys('Test Study')
		study_form.find_element(:id, 'study_embargo').send_keys('2016-12-31')
		public = study_form.find_element(:id, 'study_public')
		public.send_keys('Yes')
		# add a share
		share = @driver.find_element(:id, 'add-study-share')
		@wait.until {share.displayed? == true}
		share.click
		share_email = study_form.find_element(:class, 'share-email')
		share_email.send_keys($share_email)
		share_permission = study_form.find_element(:class, 'share-permission')
		share_permission.send_keys('Edit')
		# save study
		save_study = @driver.find_element(:id, 'save-study')
		save_study.click

		# upload expression matrix
		close_modal('message_modal')
		upload_expression = @driver.find_element(:id, 'upload-expression')
		upload_expression.send_keys(@test_data_path + 'expression_matrix_example.txt')
		wait_for_render(:id, 'start-file-upload')
		upload_btn = @driver.find_element(:id, 'start-file-upload')
		upload_btn.click
		# close success modal
		wait_for_render(:id, 'upload-success-modal')
		close_modal('upload-success-modal')

		# upload metadata
		wait_for_render(:id, 'metadata_form')
		upload_metadata = @driver.find_element(:id, 'upload-metadata')
		upload_metadata.send_keys(@test_data_path + 'metadata_example.txt')
		wait_for_render(:id, 'start-file-upload')
		upload_btn = @driver.find_element(:id, 'start-file-upload')
		upload_btn.click
		wait_for_render(:id, 'upload-success-modal')
		close_modal('upload-success-modal')

		# upload cluster
		cluster_form_1 = @driver.find_element(:class, 'initialize_ordinations_form')
		cluster_name = cluster_form_1.find_element(:class, 'filename')
		cluster_name.send_keys('Test Cluster 1')
		upload_cluster = cluster_form_1.find_element(:class, 'upload-clusters')
		upload_cluster.send_keys(@test_data_path + 'cluster_example.txt')
		wait_for_render(:id, 'start-file-upload')
		upload_btn = cluster_form_1.find_element(:id, 'start-file-upload')
		upload_btn.click
		wait_for_render(:id, 'upload-success-modal')
		close_modal('upload-success-modal')

		# upload a second cluster
		prev_btn = @driver.find_element(:id, 'prev-btn')
		prev_btn.click
		new_cluster = @driver.find_element(:class, 'add-cluster')
		new_cluster.click
		sleep(1)
		scroll_to_bottom
		# will be second instance since there are two forms
		cluster_form_2 = @driver.find_element(:class, 'new-cluster-form')
		cluster_name_2 = cluster_form_2.find_element(:class, 'filename')
		cluster_name_2.send_keys('Test Cluster 2')
		upload_cluster_2 = cluster_form_2.find_element(:class, 'upload-clusters')
		upload_cluster_2.send_keys(@test_data_path + 'cluster_2_example.txt')
		wait_for_render(:id, 'start-file-upload')
		scroll_to_bottom
		upload_btn_2 = cluster_form_2.find_element(:id, 'start-file-upload')
		upload_btn_2.click
		wait_for_render(:id, 'upload-success-modal')
		close_modal('upload-success-modal')

		# upload fastq
		wait_for_render(:class, 'initialize_fastq_form')
		upload_fastq = @driver.find_element(:class, 'upload-fastq')
		upload_fastq.send_keys(@test_data_path + 'cell_1_L1.fastq.gz')
		wait_for_render(:id, 'start-file-upload')
		upload_btn = @driver.find_element(:id, 'start-file-upload')
		upload_btn.click
		wait_for_render(:class, 'fastq-file')
		wait_for_render(:id, 'upload-success-modal')
		close_modal('upload-success-modal')
		next_btn = @driver.find_element(:id, 'next-btn')
		next_btn.click

		# upload marker gene list
		wait_for_render(:class, 'initialize_marker_genes_form')
		marker_form = @driver.find_element(:class, 'initialize_marker_genes_form')
		marker_file_name = marker_form.find_element(:id, 'study_file_name')
		marker_file_name.send_keys('Test Gene List')
		upload_markers = marker_form.find_element(:class, 'upload-marker-genes')
		upload_markers.send_keys(@test_data_path + 'marker_1_gene_list.txt')
		wait_for_render(:id, 'start-file-upload')
		upload_btn = marker_form.find_element(:id, 'start-file-upload')
		upload_btn.click
		wait_for_render(:id, 'upload-success-modal')
		close_modal('upload-success-modal')
		next_btn = @driver.find_element(:id, 'next-btn')
		next_btn.click

		# upload doc file
		wait_for_render(:class, 'initialize_misc_form')
		upload_doc = @driver.find_element(:class, 'upload-misc')
		upload_doc.send_keys(@test_data_path + 'table_1.xlsx')
		wait_for_render(:id, 'start-file-upload')
		upload_btn = @driver.find_element(:id, 'start-file-upload')
		upload_btn.click
		wait_for_render(:class, 'documentation-file')
		# close success modal
		wait_for_render(:id, 'upload-success-modal')
		close_modal('upload-success-modal')

		# change attributes on file to validate update function
		misc_form = @driver.find_element(:class, 'initialize_misc_form')
		desc_field = misc_form.find_element(:id, 'study_file_description')
		desc_field.send_keys('Supplementary table')
		save_btn = misc_form.find_element(:class, 'save-study-file')
		save_btn.click
		wait_for_render(:id, 'study-file-notices')
		close_modal('study-file-notices')
	end

	# verify that recently created study uploaded to firecloud
	test 'verify firecloud workspace' do
		path = @base_url + '/studies'
		@driver.get path
		close_modal('message_modal')
		login($test_email)

		show_study = @driver.find_element(:class, 'test-study-show')
		show_study.click

		# verify firecloud workspace creation
		firecloud_link = @driver.find_element(:id, 'firecloud-link')
		firecloud_url = 'https://portal.firecloud.org/#workspaces/single-cell-portal%3Adevelopment-test-study'
		firecloud_link.click
		@driver.switch_to.window(@driver.window_handles.last)
		# log in
		login = @driver.find_element(:class, 'button')
		login.click
		assert @driver.current_url == firecloud_url, 'did not open firecloud workspace'
		completed = @driver.find_elements(:class, 'fa-check-circle')
		assert completed.size >= 1, 'did not provision workspace properly'

		# verify gcs bucket and uploads
		@driver.switch_to.window(@driver.window_handles.first)
		gcs_link = @driver.find_element(:id, 'gcs-link')
		gcs_link.click
		@driver.switch_to.window(@driver.window_handles.last)
		files = @driver.find_elements(:class, 'p6n-clickable-row')
		assert files.size == 7, "did not find correct number of files, expected 7 but found #{files.size}"
	end

	# test to verify deleting files removes them from gcs buckets
	test 'delete study file' do
		path = @base_url + '/studies'
		@driver.get path
		close_modal('message_modal')
		login($test_email)

		# delete file to test study
		add_files = @driver.find_element(:class, 'test-study-upload')
		add_files.click
		misc_tab = @driver.find_element(:id, 'initialize_misc_form_nav')
		misc_tab.click
		form = @driver.find_element(:class, 'initialize_misc_form')
		delete = form.find_element(:class, 'delete-file')
		delete.click
		@driver.switch_to.alert.accept
		# wait a few seconds to allow delete call to propogate all the way to FireCloud
		sleep(5)

		@driver.get path
		files = @driver.find_element(:id, 'test-study-study-file-count')
		assert files.text == '6', "did not find correct number of files, expected 6 but found #{files.text}"

		# verify deletion in google
		show_study = @driver.find_element(:class, 'test-study-show')
		show_study.click
		gcs_link = @driver.find_element(:id, 'gcs-link')
		gcs_link.click
		@driver.switch_to.window(@driver.window_handles.last)
		google_files = @driver.find_elements(:class, 'p6n-clickable-row')
		assert google_files.size == 6, "did not find correct number of files, expected 6 but found #{google_files.size}"
	end

	# text gzip parsing of expression matrices
	test 'parse gzip expression matrix' do
		# log in first
		path = @base_url + '/studies/new'
		@driver.get path
		close_modal('message_modal')
		login($test_email)

		# fill out study form
		study_form = @driver.find_element(:id, 'new_study')
		study_form.find_element(:id, 'study_name').send_keys('Gzip Parse')
		# save study
		save_study = @driver.find_element(:id, 'save-study')
		save_study.click

		# upload bad expression matrix
		close_modal('message_modal')
		upload_expression = @driver.find_element(:id, 'upload-expression')
		upload_expression.send_keys(@test_data_path + 'expression_matrix_example_gzipped.txt.gz')
		wait_for_render(:id, 'start-file-upload')
		upload_btn = @driver.find_element(:id, 'start-file-upload')
		upload_btn.click
		# close modal
		wait_for_render(:id, 'upload-success-modal')
		close_modal('upload-success-modal')

		# verify parse completed
		studies_path = @base_url + '/studies'
		@driver.get studies_path
		wait_until_page_loads(studies_path)
		study_file_count = @driver.find_element(:id, 'gzip-parse-study-file-count')
		assert study_file_count.text == '1', "found incorrect number of study files; expected 1 and found #{study_file_count.text}"
	end

	# negative tests to check file parsing & validation
	# since parsing happens in background, all messaging is handled through emails
	# this test just makes sure that parsing fails and removed entries appropriately
	# your test email account should receive emails notifying of failure
	test 'create study error messaging' do
		# log in first
		path = @base_url + '/studies/new'
		@driver.get path
		close_modal('message_modal')
		login($test_email)

		# fill out study form
		study_form = @driver.find_element(:id, 'new_study')
		study_form.find_element(:id, 'study_name').send_keys('Error Messaging Test Study')
		# save study
		save_study = @driver.find_element(:id, 'save-study')
		save_study.click

		# upload bad expression matrix
		close_modal('message_modal')
		upload_expression = @driver.find_element(:id, 'upload-expression')
		upload_expression.send_keys(@test_data_path + 'expression_matrix_example_bad.txt')
		wait_for_render(:id, 'start-file-upload')
		upload_btn = @driver.find_element(:id, 'start-file-upload')
		upload_btn.click
		# close modal
		wait_for_render(:id, 'upload-success-modal')
		close_modal('upload-success-modal')

		# upload bad metadata assignments
		wait_for_render(:id, 'metadata_form')
		upload_assignments = @driver.find_element(:id, 'upload-metadata')
		upload_assignments.send_keys(@test_data_path + 'metadata_bad.txt')
		wait_for_render(:id, 'start-file-upload')
		upload_btn = @driver.find_element(:id, 'start-file-upload')
		upload_btn.click
		# close modal
		wait_for_render(:id, 'upload-success-modal')
		close_modal('upload-success-modal')

		# upload bad cluster coordinates
		upload_clusters = @driver.find_element(:class, 'upload-clusters')
		upload_clusters.send_keys(@test_data_path + 'cluster_bad.txt')
		wait_for_render(:id, 'start-file-upload')
		upload_btn = @driver.find_element(:id, 'start-file-upload')
		upload_btn.click
		# close modal
		wait_for_render(:id, 'upload-success-modal')
		close_modal('upload-success-modal')
		next_btn = @driver.find_element(:id, 'next-btn')
		next_btn.click

		# upload bad marker gene list
		marker_form = @driver.find_element(:class, 'initialize_marker_genes_form')
		marker_file_name = marker_form.find_element(:id, 'study_file_name')
		marker_file_name.send_keys('Test Gene List')
		upload_markers = @driver.find_element(:class, 'upload-marker-genes')
		upload_markers.send_keys(@test_data_path + 'marker_1_gene_list_bad.txt')
		wait_for_render(:id, 'start-file-upload')
		upload_btn = @driver.find_element(:id, 'start-file-upload')
		upload_btn.click
		# close modal
		wait_for_render(:id, 'upload-success-modal')
		close_modal('upload-success-modal')
		# wait for a few seconds to allow parses to fail fully
		sleep(3)

		# assert parses all failed and delete study
		@driver.get(@base_url + '/studies')
		wait_until_page_loads(@base_url + '/studies')
		study_file_count = @driver.find_element(:id, 'error-messaging-test-study-study-file-count')
		assert study_file_count.text == '0', "found incorrect number of study files; expected 0 and found #{study_file_count.text}"
		@driver.find_element(:class, 'error-messaging-test-study-delete').click
		@driver.switch_to.alert.accept
		wait_for_render(:id, 'message_modal')
		close_modal('message_modal')
	end

	# create private study for testing visibility/edit restrictions
	# must be run before other tests, so numbered accordingly
	test 'create private study' do
		# log in first
		path = @base_url + '/studies/new'
		@driver.get path
		close_modal('message_modal')
		login($test_email)

		# fill out study form
		study_form = @driver.find_element(:id, 'new_study')
		study_form.find_element(:id, 'study_name').send_keys('Private Study')
		public = study_form.find_element(:id, 'study_public')
		public.send_keys('No')
		# save study
		save_study = @driver.find_element(:id, 'save-study')
		save_study.click
	end

	# check visibility & edit restrictions as well as share access
	test 'create share and check view and edit' do
		# check view visibility for unauthenticated users
		path = @base_url + '/study/private-study'
		@driver.get path
		assert @driver.current_url == @base_url, 'did not redirect'
		assert element_present?(:id, 'message_modal'), 'did not find alert modal'
		close_modal('message_modal')

		# log in and get study ids for use later
		path = @base_url + '/studies'
		@driver.get path
		@driver.manage.window.maximize
		close_modal('message_modal')
		# send login info
		login($test_email)

		# get path info
		edit = @driver.find_element(:class, 'private-study-edit')
		edit.click
		sleep(2)
		private_study_id = @driver.current_url.split('/')[5]
		@driver.get @base_url + '/studies'
		edit = @driver.find_element(:class, 'test-study-edit')
		edit.click
		sleep(2)
		share_study_id = @driver.current_url.split('/')[5]

		# logout
		profile = @driver.find_element(:id, 'profile-nav')
		profile.click
		logout = @driver.find_element(:id, 'logout-nav')
		logout.click
		wait_until_page_loads(@base_url)
		close_modal('message_modal')

		# login as share user
		login_link = @driver.find_element(:id, 'login-nav')
		login_link.click
		login($share_email)

		# view study
		path = @base_url + '/study/private-study'
		@driver.get path
		assert @driver.current_url == @base_url, 'did not redirect'
		assert element_present?(:id, 'message_modal'), 'did not find alert modal'
		close_modal('message_modal')
		# check public visibility when logged in
		path = @base_url + '/study/gzip-parse'
		@driver.get path
		assert @driver.current_url == path, 'did not load public study without share'

		# edit study
		edit_path = @base_url + '/studies/' + private_study_id + '/edit'
		@driver.get edit_path
		assert @driver.current_url == @base_url + '/studies', 'did not redirect'
		assert element_present?(:id, 'message_modal'), 'did not find alert modal'
		close_modal('message_modal')

		# test share
		share_view_path = @base_url + '/study/test-study'
		@driver.get share_view_path
		assert @driver.current_url == share_view_path, 'did not load share study view'
		share_edit_path = @base_url + '/studies/' + share_study_id + '/edit'
		@driver.get share_edit_path
		assert @driver.current_url == share_edit_path, 'did not load share study edit'

	end

	##
	## FRONT END FUNCTIONALITY TESTS
	##

	test 'get home page' do
		@driver.get(@base_url)
		assert element_present?(:id, 'main-banner'), 'could not find index page title text'
		assert @driver.find_elements(:class, 'panel-primary').size >= 1, 'did not find any studies'
	end

	test 'perform search' do
		@driver.get(@base_url)
		search_box = @driver.find_element(:id, 'search_terms')
		search_box.send_keys('Test Study')
		submit = @driver.find_element(:id, 'submit-search')
		submit.click
		studies = @driver.find_elements(:class, 'study-panel').size
		assert studies == 1, 'incorrect number of studies found. expected one but found ' + studies.to_s
	end

	test 'load Test Study study' do
		path = @base_url + '/study/test-study'
		@driver.get(path)
		wait_until_page_loads(path)
		assert element_present?(:class, 'study-lead'), 'could not find study title'
		assert element_present?(:id, 'cluster-plot'), 'could not find study cluster plot'
		# load subclusters
		clusters = @driver.find_element(:id, 'cluster').find_elements(:tag_name, 'option')
		assert clusters.size == 2, 'incorrect number of clusters found'
		annotations = @driver.find_element(:id, 'annotation').find_elements(:tag_name, 'option')
		assert annotations.size == 5, 'incorrect number of annotations found'
		annotations.select {|opt| opt.text == 'Sub-Cluster'}.first.click
		@wait.until {@driver.find_elements(:class, 'traces').size == 6}
		legend = @driver.find_elements(:class, 'traces').size
		assert legend == 6, "incorrect number of traces found in Sub-Cluster, expected 6 - found #{legend}"
	end

	test 'download study data file' do
		path = @base_url + '/study/test-study'
		@driver.get(path)
		wait_until_page_loads(path)
		download_section = @driver.find_element(:id, 'study-data-files')
		# gotcha when clicking, must wait until completes
		download_section.click
		files = @driver.find_elements(:class, 'dl-link')
		file_link = files.first
		@wait.until { file_link.displayed? }
		downloaded = file_link.click
		assert downloaded == nil, 'could not click download link'
	end

	test 'search for single gene' do
		path = @base_url + '/study/test-study'
		@driver.get(path)
		wait_until_page_loads(path)
		# load random gene to search
		gene = @genes.sample
		search_box = @driver.find_element(:id, 'search_genes')
		search_box.send_key(gene)
		search_form = @driver.find_element(:id, 'search-genes-form')
		search_form.submit
		assert element_present?(:id, 'box-controls'), 'could not find expression boxplot'
		assert element_present?(:id, 'scatter-plots'), 'could not find expression scatter plots'
	end

	test 'search for multiple gene' do
		path = @base_url + '/study/test-study'
		@driver.get(path)
		wait_until_page_loads(path)
		# load random genes to search
		genes = @genes.shuffle.take(1 + rand(@genes.size) + 1)
		search_box = @driver.find_element(:id, 'search_genes')
		search_box.send_keys(genes.join(' '))
		search_form = @driver.find_element(:id, 'search-genes-form')
		search_form.submit
		assert element_present?(:id, 'plots'), 'could not find expression heatmap'
	end

	test 'load marker gene heatmap' do
		path = @base_url + '/study/test-study'
		@driver.get(path)
		wait_until_page_loads(path)
		expression_list = @driver.find_element(:id, 'gene_set')
		opts = expression_list.find_elements(:tag_name, 'option').delete_if {|o| o.text == 'Please select a gene list'}
		list = opts.sample
		list.click
		assert element_present?(:id, 'box-controls'), 'could not find marker list expression boxplot'
		assert element_present?(:id, 'scatter-plots'), 'could not find marker list expression scatter plots'
	end

	test 'load marker gene box/scatter' do
		path = @base_url + '/study/test-study'
		@driver.get(path)
		wait_until_page_loads(path)
		expression_list = @driver.find_element(:id, 'expression')
		opts = expression_list.find_elements(:tag_name, 'option').delete_if {|o| o.text == 'Please select a gene list'}
		list = opts.sample
		list.click
		assert element_present?(:id, 'plots'), 'could not find marker list expression heatmap'
	end

	test 'load different cluster and annotation then search gene expression' do
		path = @base_url + '/study/test-study'
		@driver.get(path)
		wait_until_page_loads(path)
		clusters = @driver.find_element(:id, 'cluster').find_elements(:tag_name, 'option')
		cluster = clusters.last
		cluster_name = cluster['text']
		cluster.click
		# wait for 3 seconds as new annotation options load
		sleep(3)
		annotations = @driver.find_element(:id, 'annotation').find_elements(:tag_name, 'option')
		annotation = annotations.sample
		annotation_value = annotation['value']
		annotation.click
		gene = @genes.sample
		search_box = @driver.find_element(:id, 'search_genes')
		search_box.send_key(gene)
		search_form = @driver.find_element(:id, 'search-genes-form')
		search_form.submit
		new_path = "#{@base_url}/study/test-study/gene_expression/#{gene}?annotation=#{annotation_value.split.join('+')}&boxpoints=all&cluster=#{cluster_name.split.join('+')}"
		wait_until_page_loads(new_path)
		loaded_cluster = @driver.find_element(:id, 'cluster')
		loaded_annotation = @driver.find_element(:id, 'annotation')
		assert loaded_cluster['value'] == cluster_name, "did not load correct cluster; expected #{cluster_name} but loaded #{loaded_cluster['value']}"
		assert loaded_annotation['value'] == annotation_value, "did not load correct annotation; expected #{annotation_value} but loaded #{loaded_annotation['value']}"
	end

	# test whether or not maintenance mode functions properly
	test 'enable maintenance mode' do
		# enable maintenance mode
		system("#{@base_path}/bin/enable_maintenance.sh on")
		@driver.get @base_url
		assert element_present?(:id, 'maintenance-notice'), 'could not load maintenance page'
		# disable maintenance mode
		system("#{@base_path}/bin/enable_maintenance.sh off")
		@driver.get @base_url
		assert element_present?(:id, 'main-banner'), 'could not load home page'
	end

	# test that camera position is being preserved on cluster/annotation select & rotation
	test 'check camera position on change' do
		path = @base_url + '/study/test-study'
		@driver.get(path)
		wait_until_page_loads(path)
		# wait for plot to render
		sleep(3)
		# get camera data
		camera = @driver.execute_script("return $('#cluster-plot').data('camera')")
		# set new rotation
		camera['eye']['x'] = (Random.rand * 10 - 5).round(4)
		camera['eye']['y'] = (Random.rand * 10 - 5).round(4)
		camera['eye']['z'] = (Random.rand * 10 - 5).round(4)
		# call relayout to trigger update & camera position save
		@driver.execute_script("Plotly.relayout('cluster-plot', {'scene': {'camera' : #{camera.to_json}}})")
		# get new camera
		sleep(1)
		new_camera = @driver.execute_script("return $('#cluster-plot').data('camera')")
		assert camera == new_camera['camera'], "camera position did not save correctly, expected #{camera.to_json}, got #{new_camera.to_json}"
		# load annotation
		annotations = @driver.find_element(:id, 'annotation').find_elements(:tag_name, 'option')
		annotations.select {|opt| opt.text == 'Sub-Cluster'}.first.click
		sleep(1)
		# verify camera position was saved
		annot_camera = @driver.execute_script("return $('#cluster-plot').data('camera')")
		assert camera == annot_camera['camera'], "camera position did not save correctly, expected #{camera.to_json}, got #{annot_camera.to_json}"
		# load new cluster
		clusters = @driver.find_element(:id, 'cluster').find_elements(:tag_name, 'option')
		cluster = clusters.last
		cluster.click
		sleep(1)
		# verify camera position was saved
		cluster_camera = @driver.execute_script("return $('#cluster-plot').data('camera')")
		assert camera == cluster_camera['camera'], "camera position did not save correctly, expected #{camera.to_json}, got #{cluster_camera.to_json}"
	end

	##
	## CLEANUP
	##

	# final test, remove test study that was created and used for front-end tests
	# runs last to clean up data for next test run
	test 'delete test and private study' do
		# log in first
		path = @base_url + '/studies'
		@driver.get path
		close_modal('message_modal')
		login($test_email)

		# delete test
		@driver.find_element(:class, 'test-study-delete').click
		@driver.switch_to.alert.accept
		wait_for_render(:id, 'message_modal')
		close_modal('message_modal')

		# delete private
		@driver.find_element(:class, 'private-study-delete').click
		@driver.switch_to.alert.accept
		wait_for_render(:id, 'message_modal')
		close_modal('message_modal')

		# delete gzip parse
		@driver.find_element(:class, 'gzip-parse-delete').click
		@driver.switch_to.alert.accept
		wait_for_render(:id, 'message_modal')
		close_modal('message_modal')
	end
end