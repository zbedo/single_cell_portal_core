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

    puts "\n"
  end

  # called on completion of every test (whether it passes or fails)
  def teardown
    @driver.quit
  end

  ##
  ## SYNC STUDY TESTS
  ##

  # this test depends on a workspace already existing in FireCloud called development-sync-test
  # if this study has been deleted, this test will fail until the workspace is re-created with at least
  # 3 default files for expression, metadata, one cluster, and one fastq file (using the test data from test/test_data)
  test 'admin: sync: existing workspace' do
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name}"

    # log in first
    path = @base_url + '/studies/new'
    @driver.get path
    close_modal(@driver, 'message_modal')
    login(@driver, $test_email, $test_email_password)

    # create a new study using an existing workspace, also generate a random name to validate that workspace name
    # and study name can be different
    uuid = SecureRandom.uuid
    random_name = "Sync Test #{uuid}"
    study_form = @driver.find_element(:id, 'new_study')
    study_form.find_element(:id, 'study_name').send_keys(random_name)
    study_form.find_element(:id, 'study_use_existing_workspace').send_keys('Yes')
    study_form.find_element(:id, 'study_firecloud_workspace').send_keys("development-sync-test-study")
    share = @driver.find_element(:id, 'add-study-share')
    @wait.until {share.displayed?}
    share.click
    share_email = study_form.find_element(:class, 'share-email')
    share_email.send_keys($share_email)

    # save study
    save_study = @driver.find_element(:id, 'save-study')
    save_study.click
    wait_until_page_loads(@driver, 'sync path')
    close_modal(@driver, 'message_modal')

    # sync each file
    study_file_forms = @driver.find_elements(:class, 'unsynced-study-file')
    study_file_forms.each do |form|
      filename = form.find_element(:id, 'study_file_name')['value']
      file_type = form.find_element(:id, 'study_file_file_type')
      case filename
        when 'cluster_example.txt'
          file_type.send_keys('Cluster')
        when 'expression_matrix_example.txt'
          file_type.send_keys('Expression Matrix')
        when 'metadata_example.txt'
          file_type.send_keys('Metadata')
        else
          file_type.send_keys('Other')
      end
      sync_button = form.find_element(:class, 'save-study-file')
      sync_button.click
      close_modal(@driver, 'sync-notice-modal')
    end

    # sync directory listings
    directory_forms = @driver.find_elements(:class, 'unsynced-directory-listing')
    directory_forms.each do |form|
      sync_button = form.find_element(:class, 'save-directory-listing')
      sync_button.click
      close_modal(@driver, 'sync-notice-modal')
    end

    # now assert that forms were re-rendered in synced data panel
    sync_panel = @driver.find_element(:id, 'synced-data-panel-toggle')
    sync_panel.click
    # wait a second for panel to open
    sleep(1)
    synced_files_div = @driver.find_element(:id, 'synced-study-files')
    synced_files = synced_files_div.find_elements(:tag_name, 'form')
    assert synced_files.size == study_file_forms.size, "did not find correct number of synced files, expected #{study_file_forms.size} but found #{synced_files.size}"

    synced_dirs_div = @driver.find_element(:id, 'synced-directory-listings')
    synced_dirs = synced_dirs_div.find_elements(:tag_name, 'form')
    assert synced_dirs.size == directory_forms.size, "did not find correct number of synced files, expected #{directory_forms.size} but found #{synced_dirs.size}"

    updated_files = {}
    # now use synced data forms to update entries and keep track of changes for comparison later
    synced_files.each do |sync_form|
      file_type = sync_form.find_element(:id, 'study_file_file_type')[:value]
      name = sync_form.find_element(:id, 'study_file_name')[:value]
      description = "Description for #{file_type}"
      description_field = sync_form.find_element(:id, 'study_file_description')
      description_field.send_keys(description)
      updated_files["#{sync_form[:id]}"] = {
          name: name,
          file_type: file_type,
          description: description,
          parsed: file_type != 'Other'
      }
      sync_button = sync_form.find_element(:class, 'save-study-file')
      sync_button.click
      close_modal(@driver, 'sync-notice-modal')
    end

    # update directory listings too
    updated_dirs = {}
    synced_dirs.each do |sync_form|
      name = sync_form.find_element(:id, 'directory_listing_name')[:value]
      description = "Description for #{name}"
      description_field = sync_form.find_element(:id, 'directory_listing_description')
      description_field.send_keys(description)
      updated_dirs["#{sync_form[:id]}"] = {
          description: description,
          file_type: sync_form.find_element(:id, 'directory_listing_file_type')[:value]
      }
      sync_button = sync_form.find_element(:class, 'save-directory-listing')
      sync_button.click
      close_modal(@driver, 'sync-notice-modal')
    end

    # lastly, check info page to make sure everything did in fact parse and complete
    studies_path = @base_url + '/studies'
    @driver.get studies_path
    wait_until_page_loads(@driver, studies_path)

    show_button = @driver.find_element(:class, "sync-test-#{uuid}-show")
    show_button.click
    wait_until_page_loads(@driver, 'show path')

    # assert number of files using the count badges (faster than counting table rows)
    study_file_count = @driver.find_element(:id, 'study-file-count').text.to_i
    primary_data_count = @driver.find_element(:id, 'primary-data-count').text.to_i
    other_data_count = @driver.find_element(:id, 'other-data-count').text.to_i
    assert study_file_count == study_file_forms.size, "did not find correct number of study files, expected #{study_file_forms.size} but found #{study_file_count}"
    assert primary_data_count == 1, "did not find correct number of primary data files, expected 1 but found #{primary_data_count}"
    assert other_data_count == 19, "did not find correct number of other data files, expected 19 but found #{primary_data_count}"

    # make sure edits saved by going through updated list of synced files and comparing values
    updated_files.each do |id, values|
      study_file_table_row = @driver.find_element(:id, id)
      entry_name = study_file_table_row.find_element(:class, 'study-file-name').text
      entry_file_type = study_file_table_row.find_element(:class, 'study-file-file-type').text
      entry_description = study_file_table_row.find_element(:class, 'study-file-description').text
      entry_parsed = study_file_table_row.find_element(:class, 'study-file-parsed')['data-parsed'] == 'true'
      assert values[:name] == entry_name, "study file entry #{id} name incorrect, expected #{values[:name]} but found #{entry_name}"
      assert values[:file_type] == entry_file_type, "study file entry #{id} file type incorrect, expected #{values[:file_type]} but found #{entry_file_type}"
      assert values[:description] == entry_description, "study file entry #{id} description incorrect, expected #{values[:description]} but found #{entry_description}"
      assert values[:parsed] == entry_parsed, "study file entry #{id} parse incorrect, expected #{values[:parsed]} but found #{entry_parsed}"
    end

    # now check directory listings datatables - we only need to match the first found row as all rows will have identical descriptions
    updated_dirs.each_value do |values|
      directory_listing_row = @driver.find_element(:class, values[:file_type] + '-entry')
      found_description = directory_listing_row.find_element(:class, 'dl-description')
      assert values[:description] == found_description.text, "directory listing description incorrect, expected #{values[:description]} but found #{found_description.text}"
    end

    # assert share was added
    share_email_id = 'study-share-' + $share_email.gsub(/[@.]/, '-')
    assert element_present?(@driver, :id, share_email_id), 'did not find proper share entry'
    share_row = @driver.find_element(:id, share_email_id)
    shared_email = share_row.find_element(:class, 'share-email').text
    assert shared_email == $share_email, "did not find correct email for share, expected #{$share_email} but found #{shared_email}"
    shared_permission = share_row.find_element(:class, 'share-permission').text
    assert shared_permission == 'View', "did not find correct share permissions, expected View but found #{shared_permission}"

    # now test removing items
    @driver.get(@base_url + '/studies')
    sync_button_class = random_name.split.map(&:downcase).join('-') + '-sync'
    sync_button = @driver.find_element(:class, sync_button_class)
    sync_button.click
    wait_until_page_loads(@driver, 'sync path')

    sync_panel = @driver.find_element(:id, 'synced-data-panel-toggle')
    sync_panel.click
    sleep(1)
    synced_files = @driver.find_elements(:class, 'synced-study-file')
    synced_directory_listing = @driver.find_element(:class, 'synced-directory-listing')

    # delete random file
    file_to_delete = synced_files.sample
    delete_file_btn = file_to_delete.find_element(:class, 'delete-study-file')
    delete_file_btn.click
    accept_alert(@driver)
    close_modal(@driver, 'sync-notice-modal')

    # delete directory listing
    delete_dir_btn = synced_directory_listing.find_element(:class, 'delete-directory-listing')
    delete_dir_btn.click
    accept_alert(@driver)
    close_modal(@driver, 'sync-notice-modal')
    # give DelayedJob one second to fire the DeleteQueueJob to remove the deleted entries
    sleep(1)

    # confirm files were removed
    @driver.get studies_path
    wait_until_page_loads(@driver, studies_path)
    study_file_count = @driver.find_element(:id, "sync-test-#{uuid}-study-file-count").text.to_i
    assert study_file_count == 4, "did not remove files, expected 4 but found #{study_file_count}"

    # remove share and resync
    edit_button = @driver.find_element(:class, "sync-test-#{uuid}-edit")
    edit_button.click
    wait_for_render(@driver, :class, 'study-share-form')
    # we need an extra sleep here to allow the javascript handlers to attach so that the remove_nested_fields event will fire
    sleep(0.5)
    remove_share = @driver.find_element(:class, 'remove_nested_fields')
    remove_share.click
    accept_alert(@driver)
    # let the form remove from the page
    sleep (0.25)
    save_study = @driver.find_element(:id, 'save-study')
    save_study.click
    close_modal(@driver, 'message_modal')
    sync_button = @driver.find_element(:class, "sync-test-#{uuid}-sync")
    sync_button.click
    wait_for_render(@driver, :id, 'synced-data-panel-toggle')

    # now confirm share was removed at FireCloud level
    profile = @driver.find_element(:id, 'profile-nav')
    profile.click
    logout = @driver.find_element(:id, 'logout-nav')
    logout.click
    wait_until_page_loads(@driver, @base_url)
    close_modal(@driver, 'message_modal')

    # now login as share user and check workspace
    login_path = @base_url + '/users/sign_in'
    @driver.get login_path
    wait_until_page_loads(@driver, login_path)
    login_as_other(@driver, $share_email, $share_email_password)
    firecloud_workspace = "https://portal.firecloud.org/#workspaces/single-cell-portal/sync-test-#{uuid}"
    @driver.get firecloud_workspace
    assert !element_present?(@driver, :class, 'fa-check-circle'), 'did not revoke access - study workspace still loads'

    # log back in as test user and clean up study
    @driver.get @base_url
    profile = @driver.find_element(:id, 'profile-nav')
    profile.click
    logout = @driver.find_element(:id, 'logout-nav')
    logout.click
    wait_until_page_loads(@driver, @base_url)
    close_modal(@driver, 'message_modal')
    @driver.get @base_url + '/studies'
    close_modal(@driver, 'message_modal')
    login_as_other(@driver, $test_email, $test_email_password)
    delete_local_link = @driver.find_element(:class, "sync-test-#{uuid}-delete-local")
    delete_local_link.click
    accept_alert(@driver)
    close_modal(@driver, 'message_modal')

    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name} successful!"
  end

  test 'admin: sync: restricted workspace' do
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name}"

    # log in first
    path = @base_url + '/studies/new'
    @driver.get path
    close_modal(@driver, 'message_modal')
    login(@driver, $test_email, $test_email_password)

    # attempt to create a study using a workspace with a restricted authorizationDomain
    uuid = SecureRandom.uuid
    random_name = "Restricted Sync Test #{uuid}"
    study_form = @driver.find_element(:id, 'new_study')
    study_form.find_element(:id, 'study_name').send_keys(random_name)
    study_form.find_element(:id, 'study_use_existing_workspace').send_keys('Yes')
    study_form.find_element(:id, 'study_firecloud_workspace').send_keys("development-authorization-domain-test-study")

    save_study = @driver.find_element(:id, 'save-study')
    save_study.click
    wait_for_render(@driver, :id, 'study-errors-block')
    error_message = @driver.find_element(:id, 'study-errors-block').find_element(:tag_name, 'li').text
    assert error_message.include?('The workspace you provided is restricted.'), "Did not find correct error message, expected 'The workspace you provided is restricted.' but found #{error_message}"

    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name} successful!"
  end
end