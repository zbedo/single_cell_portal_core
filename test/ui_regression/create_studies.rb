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
    @wait = Selenium::WebDriver::Wait.new(:timeout => 30)
    @test_data_path = File.expand_path(File.join('test', 'test_data')) + '/'
    @accept_next_alert = true
    @base_url = $portal_url

    puts "\n"
  end

  # called on completion of every test (whether it passes or fails)
  def teardown
    @driver.quit
  end

  ##
  ## CREATE STUDY TESTS
  ##

  # admin backend tests of entire study creation process including negative/error tests
  # uses example data in test directory as inputs (based off of https://github.com/broadinstitute/single_cell_portal/tree/master/demo_data)
  # these tests run first to create test studies to use in front-end tests later
  test 'admin: create-study: configurations: user-annotation: workflows: public' do
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name}"

    # log in first
    path = @base_url + '/studies/new'
    @driver.get path
    close_modal(@driver, 'message_modal')
    # log in as user #1
    login(@driver, $test_email, $test_email_password)

    # fill out study form
    study_form = @driver.find_element(:id, 'new_study')
    study_form.find_element(:id, 'study_name').send_keys("Test Study #{$random_seed}")
    public = study_form.find_element(:id, 'study_public')
    public.send_keys('Yes')
    # add a share
    share = @driver.find_element(:id, 'add-study-share')
    @wait.until {share.displayed?}
    share.click
    share_email = study_form.find_element(:class, 'share-email')
    share_email.send_keys($share_email)
    share_permission = study_form.find_element(:class, 'share-permission')
    share_permission.send_keys('Edit')
    # save study
    save_study = @driver.find_element(:id, 'save-study')
    save_study.click

    # upload expression matrix
    close_modal(@driver, 'message_modal')
    upload_expression = @driver.find_element(:id, 'upload-expression')
    upload_expression.send_keys(@test_data_path + 'expression_matrix_example.txt')
    wait_for_render(@driver, :id, 'start-file-upload')
    upload_btn = @driver.find_element(:id, 'start-file-upload')
    upload_btn.click
    # close success modal
    close_modal(@driver, 'upload-success-modal')

    # upload a second expression file
    new_expression = @driver.find_element(:class, 'add-expression')
    new_expression.click
    scroll_to(@driver, :bottom)
    upload_expression_2 = @driver.find_element(:id, 'upload-expression')
    upload_expression_2.send_keys(@test_data_path + 'expression_matrix_example_2.txt')
    wait_for_render(@driver, :id, 'start-file-upload')
    upload_btn = @driver.find_element(:id, 'start-file-upload')
    upload_btn.click
    # close success modal
    close_modal(@driver, 'upload-success-modal')
    next_btn = @driver.find_element(:id, 'next-btn')
    next_btn.click

    # upload metadata
    wait_for_render(@driver, :id, 'metadata_form')
    upload_metadata = @driver.find_element(:id, 'upload-metadata')
    upload_metadata.send_keys(@test_data_path + 'metadata_example2.txt')
    wait_for_render(@driver, :id, 'start-file-upload')
    upload_btn = @driver.find_element(:id, 'start-file-upload')
    upload_btn.click
    close_modal(@driver, 'upload-success-modal')

    # upload cluster
    cluster_form_1 = @driver.find_element(:class, 'initialize_ordinations_form')
    cluster_name = cluster_form_1.find_element(:class, 'filename')
    cluster_name.send_keys('Test Cluster 1')
    upload_cluster = cluster_form_1.find_element(:class, 'upload-clusters')
    upload_cluster.send_keys(@test_data_path + 'cluster_example_2.txt')
    wait_for_render(@driver, :id, 'start-file-upload')
    # add labels and axis ranges
    cluster_form_1.find_element(:id, :study_file_x_axis_min).send_key(-100)
    cluster_form_1.find_element(:id, :study_file_x_axis_max).send_key(100)
    cluster_form_1.find_element(:id, :study_file_y_axis_min).send_key(-75)
    cluster_form_1.find_element(:id, :study_file_y_axis_max).send_key(75)
    cluster_form_1.find_element(:id, :study_file_z_axis_min).send_key(-125)
    cluster_form_1.find_element(:id, :study_file_z_axis_max).send_key(125)
    cluster_form_1.find_element(:id, :study_file_x_axis_label).send_key('X Axis')
    cluster_form_1.find_element(:id, :study_file_y_axis_label).send_key('Y Axis')
    cluster_form_1.find_element(:id, :study_file_z_axis_label).send_key('Z Axis')
    # perform upload
    upload_btn = cluster_form_1.find_element(:id, 'start-file-upload')
    upload_btn.click
    close_modal(@driver, 'upload-success-modal')

    # upload a second cluster
    new_cluster = @driver.find_element(:class, 'add-cluster')
    new_cluster.click
    scroll_to(@driver, :bottom)
    # will be second instance since there are two forms
    cluster_form_2 = @driver.find_element(:class, 'new-cluster-form')
    cluster_name_2 = cluster_form_2.find_element(:class, 'filename')
    cluster_name_2.send_keys('Test Cluster 2')
    upload_cluster_2 = cluster_form_2.find_element(:class, 'upload-clusters')
    upload_cluster_2.send_keys(@test_data_path + 'cluster_2_example_2.txt')
    wait_for_render(@driver, :id, 'start-file-upload')
    scroll_to(@driver, :bottom)
    upload_btn_2 = cluster_form_2.find_element(:id, 'start-file-upload')
    upload_btn_2.click
    close_modal(@driver, 'upload-success-modal')
    next_btn = @driver.find_element(:id, 'next-btn')
    next_btn.click

    # upload right fastq
    wait_for_render(@driver, :class, 'initialize_primary_data_form')
    upload_fastq = @driver.find_element(:class, 'upload-fastq')
    upload_fastq.send_keys(@test_data_path + 'cell_1_R1_001.fastq.gz')
    wait_for_render(@driver, :id, 'start-file-upload')
    upload_btn = @driver.find_element(:id, 'start-file-upload')
    upload_btn.click
    wait_for_render(@driver, :class, 'fastq-file')
    close_modal(@driver, 'upload-success-modal')

    # upload left fastq
    add_fastq = @driver.find_element(:class, 'add-primary-data')
    add_fastq.click
    wait_for_render(@driver, :class, 'new-fastq-form')
    new_fastq_form = @driver.find_element(class: 'new-fastq-form')
    new_upload_fastq = new_fastq_form.find_element(:class, 'upload-fastq')
    new_upload_fastq.send_keys(@test_data_path + 'cell_1_I1_001.fastq.gz')
    wait_for_render(@driver, :id, 'start-file-upload')
    upload_btn = new_fastq_form.find_element(:id, 'start-file-upload')
    upload_btn.click
    close_modal(@driver, 'upload-success-modal')
    next_btn = @driver.find_element(:id, 'next-btn')
    next_btn.click

    # upload marker gene list
    wait_for_render(@driver, :class, 'initialize_marker_genes_form')
    marker_form = @driver.find_element(:class, 'initialize_marker_genes_form')
    marker_file_name = marker_form.find_element(:id, 'study_file_name')
    marker_file_name.send_keys('Test Gene List')
    upload_markers = marker_form.find_element(:class, 'upload-marker-genes')
    upload_markers.send_keys(@test_data_path + 'marker_1_gene_list.txt')
    wait_for_render(@driver, :id, 'start-file-upload')
    upload_btn = marker_form.find_element(:id, 'start-file-upload')
    upload_btn.click
    close_modal(@driver, 'upload-success-modal')
    next_btn = @driver.find_element(:id, 'next-btn')
    next_btn.click

    # upload doc file
    wait_for_render(@driver, :class, 'initialize_misc_form')
    upload_doc = @driver.find_element(:class, 'upload-misc')
    upload_doc.send_keys(@test_data_path + 'table_1.xlsx')
    wait_for_render(@driver, :id, 'start-file-upload')
    upload_btn = @driver.find_element(:id, 'start-file-upload')
    upload_btn.click
    wait_for_render(@driver, :class, 'documentation-file')
    # close success modal
    close_modal(@driver, 'upload-success-modal')

    # change attributes on file to validate update function
    misc_form = @driver.find_element(:class, 'initialize_misc_form')
    desc_field = misc_form.find_element(:id, 'study_file_description')
    desc_field.send_keys('Supplementary table')
    save_btn = misc_form.find_element(:class, 'save-study-file')
    save_btn.click
    wait_for_render(@driver, :id, 'study-file-notices')
    close_modal(@driver, 'study-file-notices')

    # now check newly created study info page
    studies_path = @base_url + '/studies'
    @driver.get studies_path

    show_study = @driver.find_element(:class, "test-study-#{$random_seed}-show")
    show_study.click

    # verify that counts are correct, this will ensure that everything uploaded & parsed correctly
    cell_count = @driver.find_element(:id, 'cell-count').text.to_i
    gene_count = @driver.find_element(:id, 'gene-count').text.to_i
    cluster_count = @driver.find_element(:id, 'cluster-count').text.to_i
    gene_list_count = @driver.find_element(:id, 'precomputed-count').text.to_i
    metadata_count = @driver.find_element(:id, 'metadata-count').text.to_i
    cluster_annot_count = @driver.find_element(:id, 'cluster-annotation-count').text.to_i
    study_file_count = @driver.find_element(:id, 'study-file-count').text.to_i
    primary_data_count = @driver.find_element(:id, 'primary-data-count').text.to_i
    share_count = @driver.find_element(:id, 'share-count').text.to_i

    assert cell_count == 30, "did not find correct number of cells, expected 30 but found #{cell_count}"
    assert gene_count == 19, "did not find correct number of genes, expected 19 but found #{gene_count}"
    assert cluster_count == 2, "did not find correct number of clusters, expected 2 but found #{cluster_count}"
    assert gene_list_count == 1, "did not find correct number of gene lists, expected 1 but found #{gene_list_count}"
    assert metadata_count == 3, "did not find correct number of metadata objects, expected 3 but found #{metadata_count}"
    assert cluster_annot_count == 3, "did not find correct number of cluster annotations, expected 2 but found #{cluster_annot_count}"
    assert study_file_count == 7, "did not find correct number of study files, expected 7 but found #{study_file_count}"
    assert primary_data_count == 2, "did not find correct number of primary data files, expected 2 but found #{primary_data_count}"
    assert share_count == 1, "did not find correct number of study shares, expected 1 but found #{share_count}"

    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name} successful!"
  end

  #create a 2d scatter study for use in user annotation testing
  test 'admin: create-study: user-annotation: 2d' do
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name}"

    # log in first
    path = @base_url + '/studies/new'
    @driver.get path
    close_modal(@driver, 'message_modal')
    # log in as user #1
    login(@driver, $test_email, $test_email_password)

    # fill out study form
    study_form = @driver.find_element(:id, 'new_study')
    study_form.find_element(:id, 'study_name').send_keys("twod Study #{$random_seed}")
    public = study_form.find_element(:id, 'study_public')
    public.send_keys('Yes')
    # add a share
    share = @driver.find_element(:id, 'add-study-share')
    @wait.until {share.displayed?}
    share.click
    share_email = study_form.find_element(:class, 'share-email')
    share_email.send_keys($share_email)
    share_permission = study_form.find_element(:class, 'share-permission')
    share_permission.send_keys('Edit')
    # save study
    save_study = @driver.find_element(:id, 'save-study')
    save_study.click

    # upload expression matrix
    close_modal(@driver, 'message_modal')
    upload_expression = @driver.find_element(:id, 'upload-expression')
    upload_expression.send_keys(@test_data_path + 'expression_matrix_example.txt')
    wait_for_render(@driver, :id, 'start-file-upload')
    upload_btn = @driver.find_element(:id, 'start-file-upload')
    upload_btn.click
    # close success modal
    close_modal(@driver, 'upload-success-modal')
    next_btn = @driver.find_element(:id, 'next-btn')
    next_btn.click

    # upload metadata
    wait_for_render(@driver, :id, 'metadata_form')
    upload_metadata = @driver.find_element(:id, 'upload-metadata')
    upload_metadata.send_keys(@test_data_path + 'metadata_example.txt')
    wait_for_render(@driver, :id, 'start-file-upload')
    upload_btn = @driver.find_element(:id, 'start-file-upload')
    upload_btn.click
    close_modal(@driver, 'upload-success-modal')

    # upload cluster
    cluster_form_1 = @driver.find_element(:class, 'initialize_ordinations_form')
    cluster_name = cluster_form_1.find_element(:class, 'filename')
    cluster_name.send_keys('Test Cluster 1')
    upload_cluster = cluster_form_1.find_element(:class, 'upload-clusters')
    upload_cluster.send_keys(@test_data_path + 'cluster_2d_example.txt')
    wait_for_render(@driver, :id, 'start-file-upload')

    # perform upload
    upload_btn = cluster_form_1.find_element(:id, 'start-file-upload')
    upload_btn.click
    close_modal(@driver, 'upload-success-modal')

    # upload marker gene list
    scroll_to(@driver, :top)
    gene_list_tab = @driver.find_element(:id, 'initialize_marker_genes_form_nav')
    gene_list_tab.click
    marker_form = @driver.find_element(:class, 'initialize_marker_genes_form')
    marker_file_name = marker_form.find_element(:id, 'study_file_name')
    marker_file_name.send_keys('Test Gene List')
    upload_markers = marker_form.find_element(:class, 'upload-marker-genes')
    upload_markers.send_keys(@test_data_path + 'marker_1_gene_list.txt')
    wait_for_render(@driver, :id, 'start-file-upload')
    upload_btn = marker_form.find_element(:id, 'start-file-upload')
    upload_btn.click
    close_modal(@driver, 'upload-success-modal')

    # confirm all files uploaded
    studies_path = @base_url + '/studies'
    @driver.get studies_path

    study_file_count = @driver.find_element(:id, "twod-study-#{$random_seed}-study-file-count").text.to_i
    assert study_file_count == 4, "did not find correct number of files, expected 4 but found #{study_file_count}"

    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name} successful!"
  end

  # verify that recently created study uploaded to firecloud
  test 'admin: create-study: verify firecloud workspace' do
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name}"

    path = @base_url + '/studies'
    @driver.get path
    close_modal(@driver, 'message_modal')
    login(@driver, $test_email, $test_email_password)

    show_study = @driver.find_element(:class, "test-study-#{$random_seed}-show")
    show_study.click

    # verify firecloud workspace creation
    firecloud_link = @driver.find_element(:id, 'firecloud-link')
    firecloud_url = "https://portal.firecloud.org/#workspaces/single-cell-portal/#{$env}-test-study-#{$random_seed}"
    firecloud_link.click
    @driver.switch_to.window(@driver.window_handles.last)
    completed = @driver.find_elements(:class, 'fa-check-circle')
    assert completed.size >= 1, 'did not provision workspace properly'
    assert @driver.current_url == firecloud_url, 'did not open firecloud workspace'

    # verify gcs bucket and uploads
    @driver.switch_to.window(@driver.window_handles.first)
    gcs_link = @driver.find_element(:id, 'gcs-link')
    gcs_link.click
    @driver.switch_to.window(@driver.window_handles.last)
    table = @driver.find_element(:id, 'p6n-storage-objects-table')
    table_body = table.find_element(:tag_name, 'tbody')
    files = table_body.find_elements(:tag_name, 'tr')
    assert files.size == 9, "did not find correct number of files, expected 9 but found #{files.size}"
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name} successful!"
  end

  # test to verify deleting files removes them from gcs buckets
  test 'admin: delete study file' do
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name}"

    path = @base_url + '/studies'
    @driver.get path
    close_modal(@driver, 'message_modal')
    login(@driver, $test_email, $test_email_password)

    add_files = @driver.find_element(:class, "test-study-#{$random_seed}-upload")
    add_files.click
    misc_tab = @driver.find_element(:id, 'initialize_misc_form_nav')
    misc_tab.click

    # test abort functionality first
    add_misc = @driver.find_element(:class, 'add-misc')
    add_misc.click
    new_misc_form = @driver.find_element(:class, 'new-misc-form')
    upload_doc = new_misc_form.find_element(:class, 'upload-misc')
    upload_doc.send_keys(@test_data_path + 'README.txt')
    wait_for_render(@driver, :id, 'start-file-upload')
    cancel = @driver.find_element(:class, 'cancel')
    cancel.click
    sleep(3)
    close_modal(@driver, 'study-file-notices')

    # delete file from test study
    form = @driver.find_element(:class, 'initialize_misc_form')
    delete = form.find_element(:class, 'delete-file')
    delete.click
    accept_alert(@driver)

    # wait a few seconds to allow delete call to propogate all the way to FireCloud after confirmation modal
    close_modal(@driver, 'study-file-notices')
    sleep(3)

    @driver.get path
    files = @driver.find_element(:id, "test-study-#{$random_seed}-study-file-count")
    assert files.text == '8', "did not find correct number of files, expected 8 but found #{files.text}"

    # verify deletion in google
    show_study = @driver.find_element(:class, "test-study-#{$random_seed}-show")
    show_study.click
    gcs_link = @driver.find_element(:id, 'gcs-link')
    gcs_link.click
    @driver.switch_to.window(@driver.window_handles.last)
    table = @driver.find_element(:id, 'p6n-storage-objects-table')
    table_body = table.find_element(:tag_name, 'tbody')
    files = table_body.find_elements(:tag_name, 'tr')
    assert files.size == 8, "did not find correct number of files, expected 8 but found #{files.size}"
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name} successful!"
  end

  # text gzip parsing of expression matrices
  test 'admin: create-study: gzip expression matrix' do
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name}"

    # log in first
    path = @base_url + '/studies/new'
    @driver.get path
    close_modal(@driver, 'message_modal')
    login(@driver, $test_email, $test_email_password)

    # fill out study form
    study_form = @driver.find_element(:id, 'new_study')
    study_form.find_element(:id, 'study_name').send_keys("Gzip Parse #{$random_seed}")
    # save study
    save_study = @driver.find_element(:id, 'save-study')
    save_study.click

    # upload bad expression matrix
    close_modal(@driver, 'message_modal')
    upload_expression = @driver.find_element(:id, 'upload-expression')
    upload_expression.send_keys(@test_data_path + 'expression_matrix_example_gzipped.txt.gz')
    wait_for_render(@driver, :id, 'start-file-upload')
    upload_btn = @driver.find_element(:id, 'start-file-upload')
    upload_btn.click
    # close modal
    close_modal(@driver, 'upload-success-modal')

    # verify parse completed
    studies_path = @base_url + '/studies'
    @driver.get studies_path
    wait_until_page_loads(@driver, studies_path)
    study_file_count = @driver.find_element(:id, "gzip-parse-#{$random_seed}-study-file-count")
    assert study_file_count.text == '1', "found incorrect number of study files; expected 1 and found #{study_file_count.text}"
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name} successful!"
  end

  # test embargo functionality
  test 'admin: create-study: embargo' do
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name}"

    # log in first
    path = @base_url + '/studies/new'
    @driver.get path
    close_modal(@driver, 'message_modal')
    login(@driver, $test_email, $test_email_password)

    # fill out study form
    study_form = @driver.find_element(:id, 'new_study')
    study_form.find_element(:id, 'study_name').send_keys("Embargo Study #{$random_seed}")
    embargo_date = (Date.today + 1).to_s
    study_form.find_element(:id, 'study_embargo').send_keys(embargo_date)
    # save study
    save_study = @driver.find_element(:id, 'save-study')
    save_study.click

    # upload expression matrix
    close_modal(@driver, 'message_modal')
    upload_expression = @driver.find_element(:id, 'upload-expression')
    upload_expression.send_keys(@test_data_path + 'expression_matrix_example.txt')
    wait_for_render(@driver, :id, 'start-file-upload')
    upload_btn = @driver.find_element(:id, 'start-file-upload')
    upload_btn.click
    # close modal
    close_modal(@driver, 'upload-success-modal')

    # verify user can still download data
    embargo_url = @base_url + "/study/embargo-study-#{$random_seed}"
    @driver.get embargo_url
    @wait.until {element_present?(@driver, :id, 'study-download')}
    open_ui_tab(@driver, 'study-download')
    download_links = @driver.find_elements(:class, 'dl-link')
    assert download_links.size == 1, "did not find correct number of download links, expected 1 but found #{download_links.size}"

    # logout
    profile = @driver.find_element(:id, 'profile-nav')
    profile.click
    logout = @driver.find_element(:id, 'logout-nav')
    logout.click
    wait_until_page_loads(@driver, @base_url)
    close_modal(@driver, 'message_modal')

    # login as share user
    login_link = @driver.find_element(:id, 'login-nav')
    login_link.click
    login_as_other(@driver, $share_email, $share_email_password)

    # now assert download links do not load
    @driver.get embargo_url
    @wait.until {element_present?(@driver, :id, 'study-download')}
    open_ui_tab(@driver, 'study-download')
    embargo_links = @driver.find_elements(:class, 'embargoed-file')
    assert embargo_links.size == 1, "did not find correct number of embargo links, expected 1 but found #{embargo_links.size}"

    # make sure embargo redirect is in place
    data_url = @base_url + "/data/public/embargo-study-#{$random_seed}/expression_matrix_example.txt"
    @driver.get data_url
    wait_for_render(@driver, :id, 'message_modal')
    alert_text = @driver.find_element(:id, 'alert-content').text
    expected_alert = "You may not download any data from this study until #{(Date.today + 1).strftime("%B %-d, %Y")}."
    assert alert_text == expected_alert, "did not find correct alert, expected '#{expected_alert}' but found '#{alert_text}'"

    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name} successful!"
  end

  # negative tests to check file parsing & validation
  # since parsing happens in background, all messaging is handled through emails
  # this test just makes sure that parsing fails and removed entries appropriately
  # your test email account should receive emails notifying of failure
  test 'admin: create-study: file validations' do
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name}"

    # log in first
    path = @base_url + '/studies/new'
    @driver.get path
    close_modal(@driver, 'message_modal')
    login(@driver, $test_email, $test_email_password)

    # fill out study form
    study_form = @driver.find_element(:id, 'new_study')
    study_form.find_element(:id, 'study_name').send_keys("Error Messaging Test Study #{$random_seed}")
    # save study
    save_study = @driver.find_element(:id, 'save-study')
    save_study.click

    # upload bad expression matrix
    close_modal(@driver, 'message_modal')
    upload_expression = @driver.find_element(:id, 'upload-expression')
    upload_expression.send_keys(@test_data_path + 'expression_matrix_example_bad.txt')
    wait_for_render(@driver, :id, 'start-file-upload')
    upload_btn = @driver.find_element(:id, 'start-file-upload')
    upload_btn.click
    # close modal
    close_modal(@driver, 'upload-success-modal')
    next_btn = @driver.find_element(:id, 'next-btn')
    next_btn.click

    # upload bad metadata assignments
    wait_for_render(@driver, :id, 'metadata_form')
    upload_assignments = @driver.find_element(:id, 'upload-metadata')
    upload_assignments.send_keys(@test_data_path + 'metadata_bad.txt')
    wait_for_render(@driver, :id, 'start-file-upload')
    upload_btn = @driver.find_element(:id, 'start-file-upload')
    upload_btn.click
    # close modal
    close_modal(@driver, 'upload-success-modal')

    # upload bad cluster coordinates
    upload_clusters = @driver.find_element(:class, 'upload-clusters')
    upload_clusters.send_keys(@test_data_path + 'cluster_bad.txt')
    wait_for_render(@driver, :id, 'start-file-upload')
    upload_btn = @driver.find_element(:id, 'start-file-upload')
    upload_btn.click
    # close modal
    close_modal(@driver, 'upload-success-modal')

    # upload bad marker gene list
    scroll_to(@driver, :top)
    gene_list_tab = @driver.find_element(:id, 'initialize_marker_genes_form_nav')
    gene_list_tab.click
    marker_form = @driver.find_element(:class, 'initialize_marker_genes_form')
    marker_file_name = marker_form.find_element(:id, 'study_file_name')
    marker_file_name.send_keys('Test Gene List')
    upload_markers = @driver.find_element(:class, 'upload-marker-genes')
    upload_markers.send_keys(@test_data_path + 'marker_1_gene_list_bad.txt')
    wait_for_render(@driver, :id, 'start-file-upload')
    upload_btn = @driver.find_element(:id, 'start-file-upload')
    upload_btn.click
    # close modal
    close_modal(@driver, 'upload-success-modal')
    # wait for a few seconds to allow parses to fail fully
    sleep(3)

    # assert parses all failed and delete study
    @driver.get(@base_url + '/studies')
    wait_until_page_loads(@driver, @base_url + '/studies')
    study_file_count = @driver.find_element(:id, "error-messaging-test-study-#{$random_seed}-study-file-count")
    assert study_file_count.text == '0', "found incorrect number of study files; expected 0 and found #{study_file_count.text}"
    @driver.find_element(:class, "error-messaging-test-study-#{$random_seed}-delete").click
    accept_alert(@driver)
    close_modal(@driver, 'message_modal')
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name} successful!"
  end

  # create private study for testing visibility/edit restrictions
  # must be run before other tests, so numbered accordingly
  test 'admin: create-study: private' do
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name}"

    # log in first
    path = @base_url + '/studies/new'
    @driver.get path
    close_modal(@driver, 'message_modal')
    login(@driver, $test_email, $test_email_password)

    # fill out study form
    study_form = @driver.find_element(:id, 'new_study')
    study_form.find_element(:id, 'study_name').send_keys("Private Study #{$random_seed}")
    public = study_form.find_element(:id, 'study_public')
    public.send_keys('No')
    # save study
    save_study = @driver.find_element(:id, 'save-study')
    save_study.click

    # upload expression matrix
    close_modal(@driver, 'message_modal')
    upload_expression = @driver.find_element(:id, 'upload-expression')
    upload_expression.send_keys(@test_data_path + 'expression_matrix_example.txt')
    wait_for_render(@driver, :id, 'start-file-upload')
    upload_btn = @driver.find_element(:id, 'start-file-upload')
    upload_btn.click
    # close success modal
    close_modal(@driver, 'upload-success-modal')
    next_btn = @driver.find_element(:id, 'next-btn')
    next_btn.click

    # upload metadata
    wait_for_render(@driver, :id, 'metadata_form')
    upload_metadata = @driver.find_element(:id, 'upload-metadata')
    upload_metadata.send_keys(@test_data_path + 'metadata_example.txt')
    wait_for_render(@driver, :id, 'start-file-upload')
    upload_btn = @driver.find_element(:id, 'start-file-upload')
    upload_btn.click
    close_modal(@driver, 'upload-success-modal')

    # upload cluster
    cluster_form_1 = @driver.find_element(:class, 'initialize_ordinations_form')
    cluster_name = cluster_form_1.find_element(:class, 'filename')
    cluster_name.send_keys('Test Cluster 1')
    upload_cluster = cluster_form_1.find_element(:class, 'upload-clusters')
    upload_cluster.send_keys(@test_data_path + 'cluster_example.txt')
    wait_for_render(@driver, :id, 'start-file-upload')
    upload_btn = @driver.find_element(:id, 'start-file-upload')
    upload_btn.click
    close_modal(@driver, 'upload-success-modal')

    # upload marker gene list
    scroll_to(@driver, :top)
    gene_list_tab = @driver.find_element(:id, 'initialize_marker_genes_form_nav')
    gene_list_tab.click
    marker_form = @driver.find_element(:class, 'initialize_marker_genes_form')
    marker_file_name = marker_form.find_element(:id, 'study_file_name')
    marker_file_name.send_keys('Test Gene List')
    upload_markers = marker_form.find_element(:class, 'upload-marker-genes')
    upload_markers.send_keys(@test_data_path + 'marker_1_gene_list.txt')
    wait_for_render(@driver, :id, 'start-file-upload')
    upload_btn = marker_form.find_element(:id, 'start-file-upload')
    upload_btn.click
    close_modal(@driver, 'upload-success-modal')
    next_btn = @driver.find_element(:id, 'next-btn')
    next_btn.click

    # add misc file
    add_misc = @driver.find_element(:class, 'add-misc')
    add_misc.click
    new_misc_form = @driver.find_element(:class, 'new-misc-form')
    upload_doc = new_misc_form.find_element(:class, 'upload-misc')
    upload_doc.send_keys(@test_data_path + 'README.txt')
    wait_for_render(@driver, :id, 'start-file-upload')
    upload_btn = @driver.find_element(:id, 'start-file-upload')
    upload_btn.click
    # close modal
    close_modal(@driver, 'upload-success-modal')

    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name} successful!"
  end

  # check visibility & edit restrictions as well as share access
  # will also verify FireCloud ACL settings on shares
  test 'admin: sharing: view and edit permission' do
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name}"

    # check view visibility for unauthenticated users
    path = @base_url + "/study/private-study-#{$random_seed}"
    @driver.get path
    assert @driver.current_url == @base_url, 'did not redirect'
    assert element_present?(@driver, :id, 'message_modal'), 'did not find alert modal'
    close_modal(@driver, 'message_modal')

    # log in and get study ids for use later
    path = @base_url + '/studies'
    @driver.get path
    close_modal(@driver, 'message_modal')

    # send login info
    login(@driver, $test_email, $test_email_password)

    # get path info
    edit = @driver.find_element(:class, "private-study-#{$random_seed}-edit")
    edit.click
    # wait a few seconds for page to load before getting url
    sleep(2)
    private_study_id = @driver.current_url.split('/')[5]
    @driver.get @base_url + '/studies'
    edit = @driver.find_element(:class, "test-study-#{$random_seed}-edit")
    edit.click
    # wait a few seconds for page to load before getting url
    sleep(2)
    share_study_id = @driver.current_url.split('/')[5]

    # logout
    profile = @driver.find_element(:id, 'profile-nav')
    profile.click
    logout = @driver.find_element(:id, 'logout-nav')
    logout.click
    wait_until_page_loads(@driver, @base_url)
    close_modal(@driver, 'message_modal')

    # login as share user
    login_link = @driver.find_element(:id, 'login-nav')
    login_link.click
    login_as_other(@driver, $share_email, $share_email_password)

    # view study
    path = @base_url + "/study/private-study-#{$random_seed}"
    @driver.get path
    assert @driver.current_url == @base_url, 'did not redirect'
    assert element_present?(@driver, :id, 'message_modal'), 'did not find alert modal'
    close_modal(@driver, 'message_modal')
    # check public visibility when logged in
    path = @base_url + "/study/gzip-parse-#{$random_seed}"
    @driver.get path
    assert @driver.current_url == path, 'did not load public study without share'

    # edit study
    edit_path = @base_url + '/studies/' + private_study_id + '/edit'
    @driver.get edit_path
    assert @driver.current_url == @base_url + '/studies', 'did not redirect'
    assert element_present?(@driver, :id, 'message_modal'), 'did not find alert modal'
    close_modal(@driver, 'message_modal')

    # test share
    share_view_path = @base_url + "/study/test-study-#{$random_seed}"
    @driver.get share_view_path
    assert @driver.current_url == share_view_path, 'did not load share study view'
    share_edit_path = @base_url + '/studies/' + share_study_id + '/edit'
    @driver.get share_edit_path
    assert @driver.current_url == share_edit_path, 'did not load share study edit'

    # test uploading a file
    upload_path = @base_url + '/studies/' + share_study_id + '/upload'
    @driver.get upload_path
    misc_tab = @driver.find_element(:id, 'initialize_misc_form_nav')
    misc_tab.click

    upload_doc = @driver.find_element(:class, 'upload-misc')
    upload_doc.send_keys(@test_data_path + 'README.txt')
    upload_btn = @driver.find_element(:id, 'start-file-upload')
    upload_btn.click
    close_modal(@driver, 'upload-success-modal')

    # verify upload has completed and is in FireCloud bucket
    @driver.get @base_url + '/studies/'
    file_count = @driver.find_element(:id, "test-study-#{$random_seed}-study-file-count")
    assert file_count.text == '9', "did not find correct number of files, expected 9 but found #{file_count.text}"
    show_study = @driver.find_element(:class, "test-study-#{$random_seed}-show")
    show_study.click
    gcs_link = @driver.find_element(:id, 'gcs-link')
    gcs_link.click
    @driver.switch_to.window(@driver.window_handles.last)
    table = @driver.find_element(:id, 'p6n-storage-objects-table')
    table_body = table.find_element(:tag_name, 'tbody')
    files = table_body.find_elements(:tag_name, 'tr')
    assert files.size == 9, "did not find correct number of files, expected 9 but found #{files.size}"
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name} successful!"
  end
end