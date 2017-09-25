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

  # test creating sample entities for workflows
  test 'front-end: workflows: import sample entities' do
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name}"

    login_path = @base_url + '/users/sign_in'
    @driver.get login_path
    wait_until_page_loads(@driver, login_path)
    login(@driver, $test_email, $test_email_password)

    study_page = @base_url + "/study/test-study-#{$random_seed}"
    @driver.get study_page
    wait_until_page_loads(@driver, study_page)

    open_ui_tab(@driver, 'study-workflows')
    wait_for_render(@driver, :id, 'submissions-table')
    # select all available fastq files to create a sample entity
    study_data_select = Selenium::WebDriver::Support::Select.new(@driver.find_element(:id, 'workflow_study_data'))
    study_data_select.select_all
    scroll_to(@driver, :bottom)
    save_samples = @driver.find_element(:id, 'save-workspace-samples')
    save_samples.click
    close_modal(@driver, 'message_modal')

    # test export button
    export_samples = @driver.find_element(:id, 'export-sample-info')
    export_samples.click
    # wait for export to complete
    sleep(3)
    filename = 'sample_info.txt'
    sample_info_file = File.open(File.join($download_dir, filename))
    assert File.exist?(sample_info_file.path), 'Did not find exported sample info file'
    file_contents = sample_info_file.readlines
    assert file_contents.size == 2, "Sample info file is wrong size; exprected 2 lines but found #{file_contents.size}"
    header_line = "entity:sample_id\tfastq_file_1\tfastq_file_2\tfastq_file_3\tfastq_file_4\n"
    assert file_contents.first == header_line, "sample info header line incorrect, expected #{header_line} but found '#{file_contents.first}'"
    sample_line = "cell_1\tcell_1_R1_001.fastq.gz\t\tcell_1_I1_001.fastq.gz\t\n"
    assert file_contents.last == sample_line, "sample info content line incorrect, expected #{sample_line} but found '#{file_contents.last}'"

    # clean up
    sample_info_file.close
    File.delete(File.join($download_dir, filename))

    # clear samples table
    clear_btn = @driver.find_element(:id, 'clear-sample-info')
    clear_btn.click

    # now select sample
    study_samples = Selenium::WebDriver::Support::Select.new(@driver.find_element(:id, 'workflow_samples'))
    study_samples.select_all
    # wait for table to populate (will have a row with sorting_1 class)
    @wait.until {@driver.find_element(:id, 'samples-table').find_element(:class, 'sorting_1').displayed?}

    # assert samples loaded correctly
    sample_table_body = @driver.find_element(:id, 'samples-table').find_element(:tag_name, 'tbody')
    sample_rows = sample_table_body.find_elements(:tag_name, 'tr')
    assert sample_rows.size == 1, "Did not find correct number of samples in table, expected 1 but found '#{sample_rows.size}'"
    sample_name = sample_rows.first.find_element(:tag_name, 'td')
    assert sample_name.text == 'cell_1', "Did not find correct sample name, expected 'cell_1' but found '#{sample_name.text}'"

    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name} successful!"
  end

  # test creating & cancelling submissions of workflows
  test 'front-end: workflows: launch and cancel submissions' do
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name}"

    login_path = @base_url + '/users/sign_in'
    @driver.get login_path
    wait_until_page_loads(@driver, login_path)
    login(@driver, $test_email, $test_email_password)

    study_page = @base_url + "/study/test-study-#{$random_seed}"
    @driver.get study_page
    wait_until_page_loads(@driver, study_page)

    # select worfklow & sample
    open_ui_tab(@driver, 'study-workflows')
    wait_for_render(@driver, :id, 'submissions-table')
    wdl_workdropdown = @driver.find_element(:id, 'workflow_identifier')
    wdl_workflows = wdl_workdropdown.find_elements(:tag_name, 'option')
    wdl_workflows.last.click
    study_samples = Selenium::WebDriver::Support::Select.new(@driver.find_element(:id, 'workflow_samples'))
    study_samples.select_all
    # wait for table to populate (will have a row with sorting_1 class)
    @wait.until {@driver.find_element(:id, 'samples-table').find_element(:class, 'sorting_1').displayed?}

    # submit workflow
    submit_btn = @driver.find_element(id: 'submit-workflow')
    submit_btn.click
    close_modal(@driver, 'generic-update-modal')

    # abort workflow
    scroll_to(@driver, :top)
    abort_btn = @driver.find_element(:class, 'abort-submission')
    abort_btn.click
    accept_alert(@driver)
    wait_for_render(@driver, :id, 'generic-update-modal-title')
    expected_conf = 'Submission Successfully Cancelled'
    confirmation = @driver.find_element(:id, 'generic-update-modal-title').text
    assert confirmation == expected_conf, "Did not find correct confirmation message, expected '#{expected_conf}' but found '#{confirmation}'"
    close_modal(@driver, 'generic-update-modal')

    # submit new workflow
    submit_btn = @driver.find_element(id: 'submit-workflow')
    submit_btn.click
    close_modal(@driver, 'generic-update-modal')

    # force a refresh of the table
    scroll_to(@driver, :top)
    refresh_btn = @driver.find_element(:id, 'refresh-submissions-table-top')
    refresh_btn.click
    sleep(3)

    # assert there are two workflows, one aborted and one submitted
    submissions_table = @driver.find_element(:id, 'submissions-table')
    submissions = submissions_table.find_element(:tag_name, 'tbody').find_elements(:tag_name, 'tr')
    assert submissions.size >= 2, "Did not find correct number of submissions, expected at least 2 but found #{submissions.size}"
    submissions.each do |submission|
      submission_id = submission['id']
      submission_state = @driver.find_element(:id, "submission-#{submission_id}-state").text
      submission_status = @driver.find_element(:id, "submission-#{submission_id}-status").text
      if %w(Aborting Aborted).include?(submission_state)
        assert %w(Queued Submitted Failed Aborting Aborted).include?(submission_status), "Found incorrect submissions status for aborted submission #{submission_id}: #{submission_status}"
      else
        assert %w(Queued Submitted Launching Running Succeeded).include?(submission_status), "Found incorrect submissions status for regular submission #{submission_id}: #{submission_status}"
      end
    end
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name} successful!"
  end

  # test syncing outputs from submission
  test 'front-end: workflows: sync outputs' do
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name}"

    login_path = @base_url + '/users/sign_in'
    @driver.get login_path
    wait_until_page_loads(@driver, login_path)
    login(@driver, $test_email, $test_email_password)

    study_page = @base_url + "/study/test-study-#{$random_seed}"
    @driver.get study_page
    wait_until_page_loads(@driver, study_page)
    open_ui_tab(@driver, 'study-workflows')
    wait_for_render(@driver, :id, 'submissions-table')

    # make sure submission has completed
    submissions_table = @driver.find_element(:id, 'submissions-table')
    submissions = submissions_table.find_element(:tag_name, 'tbody').find_elements(:tag_name, 'tr')
    completed_submission = submissions.find {|sub|
      sub.find_element(:class, "submission-state").text == 'Done' &&
          sub.find_element(:class, "submission-status").text == 'Succeeded'
    }
    i = 1
    while completed_submission.nil?
      omit_if i >= 36, 'Skipping test; waited 3 minutes but no submissions complete yet.'

      # puts "no completed submissions, refresh try ##{i}"
      refresh_btn = @driver.find_element(:id, 'refresh-submissions-table-top')
      refresh_btn.click
      sleep 5
      submissions_table = @driver.find_element(:id, 'submissions-table')
      submissions = submissions_table.find_element(:tag_name, 'tbody').find_elements(:tag_name, 'tr')
      completed_submission = submissions.find {|sub|
        sub.find_element(:class, "submission-state").text == 'Done' &&
            sub.find_element(:class, "submission-status").text == 'Succeeded'
      }
      i += 1
    end

    # download an output file
    outputs_btn = completed_submission.find_element(:class, 'get-submission-outputs')
    outputs_btn.click
    wait_for_render(@driver, :class, 'submission-output')
    output_download = @driver.find_element(:class, 'submission-output')
    filename = output_download['download']
    output_download.click
    # give the app a few seconds to initiate download request
    sleep(5)
    output_file = File.open(File.join($download_dir, filename))
    assert File.exist?(output_file.path), 'Did not find downloaded submission output file'
    File.delete(File.join($download_dir, filename))
    close_modal(@driver, 'generic-update-modal')

    # sync an output file
    sync_btn = completed_submission.find_element(:class, 'sync-submission-outputs')
    sync_btn.click
    wait_for_render(@driver, :class, 'unsynced-study-file')
    study_file_forms = @driver.find_elements(:class, 'unsynced-study-file')
    study_file_forms.each do |form|
      file_type = form.find_element(:id, 'study_file_file_type')
      file_type.send_keys('Other')
      sync_button = form.find_element(:class, 'save-study-file')
      sync_button.click
      close_modal(@driver, 'sync-notice-modal')
    end
    scroll_to(@driver, :bottom)
    synced_toggle = @driver.find_element(:id, 'synced-data-panel-toggle')
    synced_toggle.click
    wait_for_render(@driver, :class, 'synced-study-file')
    synced_files = @driver.find_elements(:class, 'synced-study-file')
    filenames = synced_files.map {|form| form.find_element(:class, 'filename')[:value]}
    assert !filenames.find {|file| file[/#{filename}/]}.nil?, "Did not find #{filename} in list of synced files: #{filenames.join(', ')}"

    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name} successful!"
  end

  # delete submissions from study
  test 'front-end: workflows: delete submissions' do
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name}"

    login_path = @base_url + '/users/sign_in'
    @driver.get login_path
    wait_until_page_loads(@driver, login_path)
    login(@driver, $test_email, $test_email_password)

    study_page = @base_url + "/study/test-study-#{$random_seed}"
    @driver.get study_page
    wait_until_page_loads(@driver, study_page)
    open_ui_tab(@driver, 'study-workflows')
    wait_for_render(@driver, :id, 'submissions-table')
    submissions_table = @driver.find_element(:id, 'submissions-table')
    submission_ids = submissions_table.find_element(:tag_name, 'tbody').find_elements(:tag_name, 'tr').map {|s| s['id']}.delete_if {|id| id.empty?}
    submission_ids.each do |submission_id|
      submission = @driver.find_element(:id, submission_id)
      delete_btn = submission.find_element(:class, 'delete-submission-files')
      delete_btn.click
      accept_alert(@driver)
      close_modal(@driver, 'generic-update-modal')
      # let table refresh complete
      sleep(3)
    end
    empty_table = @driver.find_element(:id, 'submissions-table')
    empty_row = empty_table.find_element(:tag_name, 'tbody').find_element(:tag_name, 'tr').find_element(:tag_name, 'td')
    assert empty_row.text == 'No data available in table', "Did not completely remove all submissions, expected 'No data available in table' but found #{empty_row.text}"

    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name} successful!"
  end

  # test deleting sample entities for workflows
  test 'front-end: workflows: delete sample entities' do
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name}"

    login_path = @base_url + '/users/sign_in'
    @driver.get login_path
    wait_until_page_loads(@driver, login_path)
    login(@driver, $test_email, $test_email_password)

    study_page = @base_url + "/study/test-study-#{$random_seed}"
    @driver.get study_page
    wait_until_page_loads(@driver, study_page)

    open_ui_tab(@driver, 'study-workflows')
    wait_for_render(@driver, :id, 'submissions-table')

    # now select sample
    study_samples = Selenium::WebDriver::Support::Select.new(@driver.find_element(:id, 'workflow_samples'))
    study_samples.select_all
    # wait for table to populate (will have a row with sorting_1 class)
    @wait.until {@driver.find_element(:id, 'samples-table').find_element(:class, 'sorting_1').displayed?}

    # delete samples
    delete_btn = @driver.find_element(:id, 'delete-workspace-samples')
    delete_btn.click
    close_modal(@driver, 'message_modal')

    empty_table = @driver.find_element(:id, 'samples-table')
    empty_row = empty_table.find_element(:tag_name, 'tbody').find_element(:tag_name, 'tr').find_element(:tag_name, 'td')
    assert empty_row.text == 'No data available in table', "Did not completely remove all samples, expected 'No data available in table' but found #{empty_row.text}"
    samples_list = @driver.find_element(:id, 'workflow_samples')
    assert samples_list['value'].empty?, "Did not delete workspace samples; samples list is not empty: ''#{samples_list['value']}''"

    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name} successful!"
  end

end
