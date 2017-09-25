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
    @genes = %w(Itm2a Sergef Chil5 Fam109a Dhx9 Ssu72 Olfr1018 Fam71e2 Eif2b2)
    @wait = Selenium::WebDriver::Wait.new(:timeout => 30)
    @accept_next_alert = true

    puts "\n"
  end

  # called on completion of every test (whether it passes or fails)
  def teardown
    @driver.quit
  end

  # Create a user annotation
  test 'front-end: user-annotation: creation' do
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name}"

    # log in
    login_path = @base_url + '/users/sign_in'
    @driver.get login_path
    wait_until_page_loads(@driver, login_path)
    login(@driver, $test_email, $test_email_password)

    # first confirm that you cannot create an annotation on a 3d study
    test_study_path = @base_url + "/study/test-study-#{$random_seed}"
    @driver.get test_study_path
    wait_until_page_loads(@driver, test_study_path)
    open_ui_tab(@driver, 'study-visualize')
    @wait.until {wait_for_plotly_render(@driver, '#cluster-plot', 'rendered')}
    select_dropdown = @driver.find_element(:id, 'create_annotations_panel')
    select_dropdown.click
    # let collapse animation complete
    sleep(2)
    enable_select_button = @driver.find_element(:id, 'toggle-scatter')
    enable_select_button.click
    alert = @driver.switch_to.alert
    alert_text = alert.text
    assert alert_text == 'You may not create annotations on 3d data.  Please select a different cluster before continuing.',
           "did not find correct alert, expected 'You may not create annotations on 3d data.  Please select a different cluster before continuing.' but found '#{}'"
    alert.accept

    # go to the 2d scatter plot study
    two_d_study_path = @base_url + "/study/twod-study-#{$random_seed}"
    @driver.get two_d_study_path
    wait_until_page_loads(@driver, two_d_study_path)
    open_ui_tab(@driver, 'study-visualize')

    # Create an annotation from the study page

    # Click selection tab
    select_dropdown = @driver.find_element(:id, 'create_annotations_panel')
    select_dropdown.click
    # let collapse animation complete
    sleep(2)

    # Enable Selection
    wait_for_render(@driver, :id, 'toggle-scatter')
    enable_select_button = @driver.find_element(:id, 'toggle-scatter')
    enable_select_button.click
    # let plot redraw
    sleep(1)

    # click box select button
    select_button = @driver.find_element(:xpath, "//a[@data-val='select']")
    select_button.click

    # get the points in the plotly trace
    points = @driver.find_elements(:class, 'point')
    el1 = points[0]

    # click on the first point
    @driver.action.click_and_hold(el1).perform

    # wait for web driver
    sleep 0.5

    # drag the cursor to another point and release it
    el2 = points[-1]
    @driver.action.move_to(el2).release.perform

    # wait for plotly and webdriver
    sleep 1.0

    # send the keys for the name of the annotation
    annotation_name = @driver.find_element(:class, 'annotation-name')
    name = "user-#{$random_seed}"
    annotation_name.send_keys(name)
    # send keys to the labels of the annotation
    annotation_labels = @driver.find_elements(:class, 'annotation-label')
    annotation_labels.each_with_index do |annot, i|
      annot.send_keys("group#{i}")
    end

    sleep 0.5

    # create the annotation
    submit_button = @driver.find_element(:id, 'selection-submit')
    submit_button.click

    close_modal(@driver, 'message_modal')

    # choose the user annotation
    annotation_dropdown = @driver.find_element(:id, 'annotation')
    annotation_dropdown.send_keys("user-#{$random_seed}")
    @wait.until {wait_for_plotly_render(@driver, '#cluster-plot', 'rendered')}

    # make sure the new annotation still renders a plot for plotly
    annot_rendered = @driver.execute_script("return $('#cluster-plot').data('rendered')")
    assert annot_rendered, "cluster plot did not finish rendering on annotation change, expected true but found #{annot_rendered}"

    @driver.find_element(:id, 'search-genes-link').click
    wait_for_render(@driver, :id, 'panel-genes-search')

    # load random gene to search
    gene = @genes.sample
    search_box = @driver.find_element(:id, 'search_genes')
    search_box.send_key(gene)
    search_genes = @driver.find_element(:id, 'perform-gene-search')
    search_genes.click

    #make sure the new annotation still renders plots for plotly
    assert element_present?(@driver, :id, 'box-controls'), 'could not find expression violin plot'
    assert element_present?(@driver, :id, 'scatter-plots'), 'could not find expression scatter plots'

    # confirm queried gene is the one returned
    queried_gene = @driver.find_element(:class, 'queried-gene')
    assert queried_gene.text == gene, "did not load the correct gene, expected #{gene} but found #{queried_gene.text}"

    # wait until violin plot renders, at this point all 3 should be done
    @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'box-rendered')}
    violin_rendered = @driver.execute_script("return $('#expression-plots').data('box-rendered')")
    assert violin_rendered, "violin plot did not finish rendering, expected true but found #{violin_rendered}"
    scatter_rendered = @driver.execute_script("return $('#expression-plots').data('scatter-rendered')")
    assert scatter_rendered, "scatter plot did not finish rendering, expected true but found #{scatter_rendered}"
    reference_rendered = @driver.execute_script("return $('#expression-plots').data('reference-rendered')")
    assert reference_rendered, "reference plot did not finish rendering, expected true but found #{reference_rendered}"

    # change to box plot
    plot_dropdown = @driver.find_element(:id, 'plot_type')
    plot_ops = plot_dropdown.find_elements(:tag_name, 'option')
    new_plot = plot_ops.select {|opt| !opt.selected?}.sample.text
    plot_dropdown.send_key(new_plot)

    # wait until box plot renders, at this point all 3 should be done
    @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'box-rendered')}
    box_rendered = @driver.execute_script("return $('#expression-plots').data('box-rendered')")
    assert box_rendered, "box plot did not finish rendering, expected true but found #{box_rendered}"
    scatter_rendered = @driver.execute_script("return $('#expression-plots').data('scatter-rendered')")
    assert scatter_rendered, "scatter plot did not finish rendering, expected true but found #{scatter_rendered}"
    reference_rendered = @driver.execute_script("return $('#expression-plots').data('reference-rendered')")
    assert reference_rendered, "reference plot did not finish rendering, expected true but found #{reference_rendered}"

    gene_sets = @driver.find_element(:id, 'gene_set')
    opts = gene_sets.find_elements(:tag_name, 'option').delete_if {|o| o.text == 'Please select a gene list'}
    list = opts.sample
    list.click
    assert element_present?(@driver, :id, 'expression-plots'), 'could not find box/scatter divs'

    # wait until violin plot renders, at this point all 3 should be done
    @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'box-rendered')}
    violin_rendered = @driver.execute_script("return $('#expression-plots').data('box-rendered')")
    assert violin_rendered, "violin plot did not finish rendering, expected true but found #{violin_rendered}"
    scatter_rendered = @driver.execute_script("return $('#expression-plots').data('scatter-rendered')")
    assert scatter_rendered, "scatter plot did not finish rendering, expected true but found #{scatter_rendered}"
    reference_rendered = @driver.execute_script("return $('#expression-plots').data('reference-rendered')")
    assert reference_rendered, "reference plot did not finish rendering, expected true but found #{reference_rendered}"

    # Create an annotation from the gene page.  Due to the size of rendered elements, the only reproducible way to click the
    # annotation selection button is to scroll to the top, close the search panel, and open the annotation panel
    scroll_to(@driver, :top)
    @driver.find_element(:id, 'search-genes-link').click
    @wait.until {!element_visible?(@driver, :id, 'panel-genes-search')}

    # Click selection tabs
    select_dropdown = @driver.find_element(:id, 'create_annotations_panel')
    select_dropdown.click
    # let collapse animation complete
    sleep(2)
    # Enable Selection
    enable_select_button = @driver.find_element(:id, 'toggle-scatter')
    enable_select_button.click
    # let plot redraw
    sleep(1)

    # select the scatter plot
    plot = @driver.find_element(:id, 'scatter-plot')

    # click box select button
    scroll_to(@driver, :bottom)
    @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'scatter-rendered')}
    select_button = @driver.find_elements(:xpath, "//a[@data-val='select']")[-1]
    select_button.click

    # get the points in the plotly trace

    points = plot.find_elements(:class, 'point')
    el1 = points[0]

    # click on the first point
    @driver.action.click_and_hold(el1).perform

    # wait for web driver
    sleep 0.5

    #drag the cursor to another point and release it
    el2 = points[-1]
    @driver.action.move_to(el2).release.perform

    #wait for plotly and webdriver
    sleep 1.0

    #send the keys for the name of the annotation
    annotation_name = @driver.find_element(:class, 'annotation-name')
    name = "user-#{$random_seed}-exp"
    annotation_name.send_keys(name)
    # send keys to the labels of the annotation
    annotation_labels = @driver.find_elements(:class, 'annotation-label')
    annotation_labels.each_with_index do |annot, i|
      annot.send_keys("group#{i}")
    end

    sleep 0.5

    #create the annotation
    submit_button = @driver.find_element(:id, 'selection-submit')
    submit_button.click

    wait_for_render(@driver, :id, 'message_modal')
    close_modal(@driver, 'message_modal')

    @driver.get two_d_study_path
    wait_until_page_loads(@driver, two_d_study_path)
    open_ui_tab(@driver, 'study-visualize')

    # choose the user annotation
    @wait.until {wait_for_plotly_render(@driver, '#cluster-plot', 'rendered')}
    annotation_dropdown = @driver.find_element(:id, 'annotation')
    annotation_dropdown.send_keys("user-#{$random_seed}-exp")
    @wait.until {wait_for_plotly_render(@driver, '#cluster-plot', 'rendered')}

    #make sure the new annotation still renders a plot for plotly
    annot_rendered = @driver.execute_script("return $('#cluster-plot').data('rendered')")
    assert annot_rendered, "cluster plot did not finish rendering on annotation change, expected true but found #{annot_rendered}"

    # load random gene to search
    gene = @genes.sample
    search_box = @driver.find_element(:id, 'search_genes')
    search_box.send_key(gene)
    wait_for_render(@driver, :id, 'perform-gene-search')
    search_genes = @driver.find_element(:id, 'perform-gene-search')
    search_genes.click

    #make sure the new annotation still renders plots for plotly
    assert element_present?(@driver, :id, 'box-controls'), 'could not find expression violin plot'
    assert element_present?(@driver, :id, 'scatter-plots'), 'could not find expression scatter plots'

    sleep 0.50

    # confirm queried gene is the one returned
    queried_gene = @driver.find_element(:class, 'queried-gene')
    assert queried_gene.text == gene, "did not load the correct gene, expected #{gene} but found #{queried_gene.text}"

    # wait until violin plot renders, at this point all 3 should be done
    @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'box-rendered')}
    violin_rendered = @driver.execute_script("return $('#expression-plots').data('box-rendered')")
    assert violin_rendered, "violin plot did not finish rendering, expected true but found #{violin_rendered}"
    scatter_rendered = @driver.execute_script("return $('#expression-plots').data('scatter-rendered')")
    assert scatter_rendered, "scatter plot did not finish rendering, expected true but found #{scatter_rendered}"
    reference_rendered = @driver.execute_script("return $('#expression-plots').data('reference-rendered')")
    assert reference_rendered, "reference plot did not finish rendering, expected true but found #{reference_rendered}"

    # change to box plot
    plot_dropdown = @driver.find_element(:id, 'plot_type')
    plot_ops = plot_dropdown.find_elements(:tag_name, 'option')
    new_plot = plot_ops.select {|opt| !opt.selected?}.sample.text
    plot_dropdown.send_key(new_plot)

    # wait until box plot renders, at this point all 3 should be done
    @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'box-rendered')}
    box_rendered = @driver.execute_script("return $('#expression-plots').data('box-rendered')")
    assert box_rendered, "box plot did not finish rendering, expected true but found #{box_rendered}"
    scatter_rendered = @driver.execute_script("return $('#expression-plots').data('scatter-rendered')")
    assert scatter_rendered, "scatter plot did not finish rendering, expected true but found #{scatter_rendered}"
    reference_rendered = @driver.execute_script("return $('#expression-plots').data('reference-rendered')")
    assert reference_rendered, "reference plot did not finish rendering, expected true but found #{reference_rendered}"

    sleep 0.5

    gene_sets = @driver.find_element(:id, 'gene_set')
    opts = gene_sets.find_elements(:tag_name, 'option').delete_if {|o| o.text == 'Please select a gene list'}
    list = opts.sample
    list.click
    assert element_present?(@driver, :id, 'expression-plots'), 'could not find box/scatter divs'

    # wait until violin plot renders, at this point all 3 should be done
    @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'box-rendered')}
    violin_rendered = @driver.execute_script("return $('#expression-plots').data('box-rendered')")
    assert violin_rendered, "violin plot did not finish rendering, expected true but found #{violin_rendered}"
    scatter_rendered = @driver.execute_script("return $('#expression-plots').data('scatter-rendered')")
    assert scatter_rendered, "scatter plot did not finish rendering, expected true but found #{scatter_rendered}"
    reference_rendered = @driver.execute_script("return $('#expression-plots').data('reference-rendered')")
    assert reference_rendered, "reference plot did not finish rendering, expected true but found #{reference_rendered}"

    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name} successful!"
  end

  # make sure editing the annotation works
  test 'front-end: user-annotation: editing' do
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name}"

    # login
    login_path = @base_url + '/users/sign_in'
    @driver.get login_path
    wait_until_page_loads(@driver, login_path)
    login(@driver, $test_email, $test_email_password)

    # load annotation panel
    annot_path = @base_url + '/user_annotations'
    @driver.get annot_path

    @driver.find_element(:class, "user-#{$random_seed}-edit").click
    wait_until_page_loads(@driver, 'edit user annotation path')

    #add 'new' to the name of annotation
    name = @driver.find_element(:id, 'user_annotation_name')
    name.send_key("new")

    #add 'new' to the labels
    annotation_labels = @driver.find_elements(:id, 'user-annotation_values')

    annotation_labels.each_with_index do |annot, i|
      annot.clear
      annot.send_keys("group#{i}new")
    end

    #update the annotation
    submit = @driver.find_element(:id, 'submit-button')
    submit.click

    wait_until_page_loads(@driver, 'user annotation path')

    #check names and labels
    new_names = @driver.find_elements(:class, 'annotation-name').map{|x| x.text }
    new_labels = @driver.find_elements(:class, "user-#{$random_seed}new").map{|x| x.text }

    #assert new name saved correctly
    assert (new_names.include? "user-#{$random_seed}new"), "Name edit failed, expected 'user-#{$random_seed}new' but got '#{new_names}'"

    #assert labels saved correctly
    assert (new_labels.include? "group0new"), "Name edit failed, expected 'new in group' but got '#{new_labels}'"
    wait_for_render(@driver, :id, 'message_modal')
    close_modal(@driver, 'message_modal')

    #View the annotation
    @driver.find_element(:class, "user-#{$random_seed}new-show").click
    wait_until_page_loads(@driver, 'view user annotation path')

    #assert the plot still renders
    @wait.until {wait_for_plotly_render(@driver, '#cluster-plot', 'rendered')}
    annot_rendered = @driver.execute_script("return $('#cluster-plot').data('rendered')")
    assert annot_rendered, "cluster plot did not finish rendering on annotation change, expected true but found #{annot_rendered}"

    #assert labels are correct
    plot_labels = @driver.find_elements(:class, "legendtext").map(&:text)
    assert (plot_labels.include? "user-#{$random_seed}new: group0new (3 points)"), "labels are incorrect: '#{plot_labels}' should include 'user-#{$random_seed}new: group0new'"

    #revert the annotation to old name and labels
    @driver.get annot_path
    @driver.find_element(:class, "user-#{$random_seed}new-edit").click
    wait_until_page_loads(@driver, 'edit user annotation path')

    #revert name
    name = @driver.find_element(:id, 'user_annotation_name')
    name.clear
    name.send_key("user-#{$random_seed}")

    #revert labels
    annotation_labels = @driver.find_elements(:id, 'user-annotation_values')

    annotation_labels.each_with_index do |annot, i|
      annot.clear
      annot.send_keys("group#{i}")
    end

    #update annotation
    submit = @driver.find_element(:id, 'submit-button')
    submit.click

    wait_until_page_loads(@driver, 'user annotation path')

    #check new names and labels
    new_names = @driver.find_elements(:class, 'annotation-name').map{|x| x.text }
    new_labels = @driver.find_elements(:class, "user-#{$random_seed}").map{|x| x.text }

    #assert new name saved correctly
    assert !(new_names.include? "user-#{$random_seed}new"), "Name edit failed, expected 'user-#{$random_seed}' but got '#{new_names}'"

    #assert labels saved correctly
    assert !(new_labels.include? "group0new"), "Name edit failed, did not expect 'new in group' but got '#{new_labels}'"

    wait_for_render(@driver, :id, 'message_modal')
    close_modal(@driver, 'message_modal')

    #View the annotation
    @driver.find_element(:class, "user-#{$random_seed}-show").click
    wait_until_page_loads(@driver, 'view user annotation path')

    #assert the plot still renders
    @wait.until {wait_for_plotly_render(@driver, '#cluster-plot', 'rendered')}
    annot_rendered = @driver.execute_script("return $('#cluster-plot').data('rendered')")
    assert annot_rendered, "cluster plot did not finish rendering on annotation change, expected true but found #{annot_rendered}"

    #assert labels are correct
    plot_labels = @driver.find_elements(:class, "legendtext").map(&:text)
    assert (plot_labels.include? "user-#{$random_seed}: group0 (3 points)"), "labels are incorrect: '#{plot_labels}' should include 'user-#{$random_seed}: group0'"

    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name} successful!"
  end

  # make sure sharing the annotation works
  test 'front-end: user-annotation: sharing' do
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name}"

    # login
    login_path = @base_url + '/users/sign_in'
    @driver.get login_path
    wait_until_page_loads(@driver, login_path)
    login(@driver, $test_email, $test_email_password)

    # load annotation panel
    annot_path = @base_url + '/user_annotations'
    @driver.get annot_path

    @driver.find_element(:class, "user-#{$random_seed}-exp-edit").click
    wait_until_page_loads(@driver, 'edit user annotation path')

    # click the share button
    share_button = @driver.find_element(:id, 'add-user-annotation-share')
    share_button.click

    share_email = @driver.find_element(:class, 'share-email')
    share_email.send_keys($share_email)

    share_permission = @driver.find_element(:class, 'share-permission')
    share_permission.send_keys('Edit')

    # update the annotation
    submit = @driver.find_element(:id, 'submit-button')
    submit.click

    wait_until_page_loads(@driver, 'user annotation path')

    # logout
    close_modal(@driver, 'message_modal')
    profile = @driver.find_element(:id, 'profile-nav')
    profile.click
    logout = @driver.find_element(:id, 'logout-nav')
    logout.click
    wait_until_page_loads(@driver, @base_url)
    close_modal(@driver, 'message_modal')

    # login
    login_as_other(@driver, $test_email, $test_email_password)
    # load annotation panel
    annot_path = @base_url + '/user_annotations'
    @driver.get annot_path

    # View the annotation
    wait_until_page_loads(@driver, 'view user annotation index')
    @driver.find_element(:class, "user-#{$random_seed}-exp-show").click
    wait_until_page_loads(@driver, 'view user annotation path')

    # make sure the new annotation still renders a plot for plotly
    @wait.until {wait_for_plotly_render(@driver, '#cluster-plot', 'rendered')}
    annot_rendered = @driver.execute_script("return $('#cluster-plot').data('rendered')")
    assert annot_rendered, "cluster plot did not finish rendering on annotation change, expected true but found #{annot_rendered}"

    # load random gene to search
    gene = @genes.sample
    search_box = @driver.find_element(:id, 'search_genes')
    search_box.send_key(gene)
    wait_for_render(@driver, :id, 'perform-gene-search')
    search_genes = @driver.find_element(:id, 'perform-gene-search')
    search_genes.click

    # make sure the new annotation still renders plots for plotly
    assert element_present?(@driver, :id, 'box-controls'), 'could not find expression violin plot'
    assert element_present?(@driver, :id, 'scatter-plots'), 'could not find expression scatter plots'

    wait_for_render(@driver, :class, 'queried-gene')
    # confirm queried gene is the one returned
    queried_gene = @driver.find_element(:class, 'queried-gene')
    assert queried_gene.text == gene, "did not load the correct gene, expected #{gene} but found #{queried_gene.text}"

    # wait until violin plot renders, at this point all 3 should be done
    @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'box-rendered')}
    violin_rendered = @driver.execute_script("return $('#expression-plots').data('box-rendered')")
    assert violin_rendered, "violin plot did not finish rendering, expected true but found #{violin_rendered}"
    scatter_rendered = @driver.execute_script("return $('#expression-plots').data('scatter-rendered')")
    assert scatter_rendered, "scatter plot did not finish rendering, expected true but found #{scatter_rendered}"
    reference_rendered = @driver.execute_script("return $('#expression-plots').data('reference-rendered')")
    assert reference_rendered, "reference plot did not finish rendering, expected true but found #{reference_rendered}"

    # change to box plot
    plot_dropdown = @driver.find_element(:id, 'plot_type')
    plot_ops = plot_dropdown.find_elements(:tag_name, 'option')
    new_plot = plot_ops.select {|opt| !opt.selected?}.sample.text
    plot_dropdown.send_key(new_plot)

    # wait until box plot renders, at this point all 3 should be done
    @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'box-rendered')}
    box_rendered = @driver.execute_script("return $('#expression-plots').data('box-rendered')")
    assert box_rendered, "box plot did not finish rendering, expected true but found #{box_rendered}"
    scatter_rendered = @driver.execute_script("return $('#expression-plots').data('scatter-rendered')")
    assert scatter_rendered, "scatter plot did not finish rendering, expected true but found #{scatter_rendered}"
    reference_rendered = @driver.execute_script("return $('#expression-plots').data('reference-rendered')")
    assert reference_rendered, "reference plot did not finish rendering, expected true but found #{reference_rendered}"

    sleep 0.5

    gene_sets = @driver.find_element(:id, 'gene_set')
    opts = gene_sets.find_elements(:tag_name, 'option').delete_if {|o| o.text == 'Please select a gene list'}
    list = opts.sample
    list.click
    assert element_present?(@driver, :id, 'expression-plots'), 'could not find box/scatter divs'

    # wait until violin plot renders, at this point all 3 should be done
    @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'box-rendered')}
    violin_rendered = @driver.execute_script("return $('#expression-plots').data('box-rendered')")
    assert violin_rendered, "violin plot did not finish rendering, expected true but found #{violin_rendered}"
    scatter_rendered = @driver.execute_script("return $('#expression-plots').data('scatter-rendered')")
    assert scatter_rendered, "scatter plot did not finish rendering, expected true but found #{scatter_rendered}"
    reference_rendered = @driver.execute_script("return $('#expression-plots').data('reference-rendered')")
    assert reference_rendered, "reference plot did not finish rendering, expected true but found #{reference_rendered}"

    # revert the annotation to old name and labels
    @driver.get annot_path
    @driver.find_element(:class, "user-#{$random_seed}-exp-edit").click
    wait_until_page_loads(@driver, 'edit user annotation path')

    # change name
    name = @driver.find_element(:id, 'user_annotation_name')
    name.clear
    name.send_key("user-#{$random_seed}-exp-Share")

    # update annotation
    submit = @driver.find_element(:id, 'submit-button')
    submit.click

    wait_until_page_loads(@driver, 'user annotation path')

    # check new names and labels
    new_names = @driver.find_elements(:class, 'annotation-name').map{|x| x.text }

    # assert new name saved correctly
    assert (new_names.include? "user-#{$random_seed}-exp-Share"), "Name edit failed, expected 'user-#{$random_seed}-exp-Share' but got '#{new_names}'"
    close_modal(@driver, 'message_modal')

    # View the annotation
    @driver.find_element(:class, "user-#{$random_seed}-exp-share-show").click
    wait_until_page_loads(@driver, 'view user annotation path')

    # assert the plot still renders
    @wait.until {wait_for_plotly_render(@driver, '#cluster-plot', 'rendered')}
    annot_rendered = @driver.execute_script("return $('#cluster-plot').data('rendered')")
    assert annot_rendered, "cluster plot did not finish rendering on annotation change, expected true but found #{annot_rendered}"

    # assert labels are correct
    plot_labels = @driver.find_elements(:class, "legendtext").map(&:text)
    assert plot_labels.include?("user-#{$random_seed}-exp-Share: group0 (3 points)"), "labels are incorrect: '#{plot_labels}' should include 'user-#{$random_seed}-exp-Share: group0'"

    # logout
    profile = @driver.find_element(:id, 'profile-nav')
    profile.click
    logout = @driver.find_element(:id, 'logout-nav')
    logout.click
    wait_until_page_loads(@driver, @base_url)
    close_modal(@driver, 'message_modal')

    # login
    login_as_other(@driver, $test_email, $test_email_password)

    # load annotation panel
    annot_path = @base_url + '/user_annotations'
    @driver.get annot_path

    @driver.find_element(:class, "user-#{$random_seed}-exp-share-edit").click
    wait_until_page_loads(@driver, 'edit user annotation path')

    # click the share button
    share_button = @driver.find_element(:id, 'add-user-annotation-share')
    share_button.click

    share_email = @driver.find_element(:class, 'share-email')
    share_email.send_keys($share_email)

    share_permission = @driver.find_element(:class, 'share-permission')
    share_permission.send_keys('View')

    # change name
    name = @driver.find_element(:id, 'user_annotation_name')
    name.clear
    name.send_key("user-#{$random_seed}-exp")

    # update the annotation
    submit = @driver.find_element(:id, 'submit-button')
    submit.click

    wait_until_page_loads(@driver, 'user annotation path')

    # logout
    close_modal(@driver, 'message_modal')
    profile = @driver.find_element(:id, 'profile-nav')
    profile.click
    logout = @driver.find_element(:id, 'logout-nav')
    logout.click
    wait_until_page_loads(@driver, @base_url)
    close_modal(@driver, 'message_modal')

    # login
    login_as_other(@driver, $share_email, $share_email_password)

    # load annotation panel
    annot_path = @base_url + '/user_annotations'
    @driver.get annot_path

    # make sure can't edit
    editable = element_present?(@driver, :class, "user-#{$random_seed}-exp-edit")
    assert !editable, 'Edit button found'

    # View the annotation
    @driver.find_element(:class, "user-#{$random_seed}-exp-show").click
    wait_until_page_loads(@driver, 'view user annotation path')

    # assert the plot still renders
    @wait.until {wait_for_plotly_render(@driver, '#cluster-plot', 'rendered')}
    annot_rendered = @driver.execute_script("return $('#cluster-plot').data('rendered')")
    assert annot_rendered, "cluster plot did not finish rendering on annotation change, expected true but found #{annot_rendered}"

    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name} successful!"
  end

  test 'front-end: user-annotation: download annotation cluster file' do
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name}"
    login_path = @base_url + '/users/sign_in'
    # downloads require login now
    @driver.get login_path
    wait_until_page_loads(@driver, login_path)
    login(@driver, $test_email, $test_email_password)

    # load annotation panel
    annot_path = @base_url + '/user_annotations'
    @driver.get annot_path

    # Click download and get filenames
    filename = (@driver.find_element(:class, "user-#{$random_seed}_cluster").attribute('innerHTML') + "_user-#{$random_seed}.txt").gsub(/ /, '_')
    basename = filename.split('.').first

    @driver.find_element(:class, "user-#{$random_seed}-download").click
    # give browser 5 seconds to initiate download
    sleep(5)
    # make sure file was actually downloaded
    file_exists = Dir.entries($download_dir).select {|f| f =~ /#{basename}/}.size >= 1 || File.exists?(File.join($download_dir, filename))
    assert file_exists, "did not find downloaded file: #{filename} in #{Dir.entries($download_dir).join(', ')}"

    # delete matching files
    Dir.glob("#{$download_dir}/*").select {|f| /#{basename}/.match(f)}.map {|f| File.delete(f)}

    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name} successful!"
  end

  # check user annotation publishing
  test 'front-end: user-annotation: publishing' do
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name}"

    # login
    login_path = @base_url + '/users/sign_in'
    @driver.get login_path
    wait_until_page_loads(@driver, login_path)
    login(@driver, $test_email, $test_email_password)

    # load annotation panel
    annot_path = @base_url + '/user_annotations'
    @driver.get annot_path

    num_annotations = @driver.find_elements(:class, 'annotation-name').length

    @driver.find_element(:class, "user-#{$random_seed}-publish").click
    accept_alert(@driver)
    close_modal(@driver, 'message_modal')

    new_num_annotations = num_annotations
    i = 0
    while new_num_annotations >= num_annotations
      if i == 5
        assert false, "Reloaded the page five times but found #{new_num_annotations} rows instead of #{num_annotations-1} rows, indicating that the annotation was not deleted."
      end
      sleep 1.0
      @driver.get annot_path
      new_num_annotations = @driver.find_elements(:class, 'annotation-name').length
      i+=1
    end

    #check new names
    new_names = @driver.find_elements(:class, 'annotation-name').map{|x| x.text }

    #assert new name saved correctly
    assert !(new_names.include? "user-#{$random_seed}"), "Persist failed, expected no 'user-#{$random_seed}' but found it"

    #Wait for the annotation to persist
    sleep 3.0

    # go to study and make sure this annotation is saved
    two_d_study_path = @base_url + "/study/twod-study-#{$random_seed}"
    @driver.get two_d_study_path
    wait_until_page_loads(@driver, two_d_study_path)
    open_ui_tab(@driver, 'study-visualize')

    # choose the newly persisted annotation
    @wait.until {wait_for_plotly_render(@driver, '#cluster-plot', 'rendered')}
    annotation_dropdown = @driver.find_element(:id, 'annotation')
    annotation_dropdown.send_keys("user-#{$random_seed}")
    @wait.until {wait_for_plotly_render(@driver, '#cluster-plot', 'rendered')}

    #make sure the new annotation still renders a plot for plotly
    annot_rendered = @driver.execute_script("return $('#cluster-plot').data('rendered')")
    assert annot_rendered, "cluster plot did not finish rendering on annotation change, expected true but found #{annot_rendered}"

    # load random gene to search
    gene = @genes.sample
    search_box = @driver.find_element(:id, 'search_genes')
    search_box.send_key(gene)
    search_genes = @driver.find_element(:id, 'perform-gene-search')
    search_genes.click

    #make sure the new annotation still renders plots for plotly
    assert element_present?(@driver, :id, 'box-controls'), 'could not find expression violin plot'
    assert element_present?(@driver, :id, 'scatter-plots'), 'could not find expression scatter plots'

    # confirm queried gene is the one returned
    queried_gene = @driver.find_element(:class, 'queried-gene')
    assert queried_gene.text == gene, "did not load the correct gene, expected #{gene} but found #{queried_gene.text}"

    # wait until violin plot renders, at this point all 3 should be done
    @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'box-rendered')}
    violin_rendered = @driver.execute_script("return $('#expression-plots').data('box-rendered')")
    assert violin_rendered, "violin plot did not finish rendering, expected true but found #{violin_rendered}"
    scatter_rendered = @driver.execute_script("return $('#expression-plots').data('scatter-rendered')")
    assert scatter_rendered, "scatter plot did not finish rendering, expected true but found #{scatter_rendered}"
    reference_rendered = @driver.execute_script("return $('#expression-plots').data('reference-rendered')")
    assert reference_rendered, "reference plot did not finish rendering, expected true but found #{reference_rendered}"

    # change to box plot
    plot_dropdown = @driver.find_element(:id, 'plot_type')
    plot_ops = plot_dropdown.find_elements(:tag_name, 'option')
    new_plot = plot_ops.select {|opt| !opt.selected?}.sample.text
    plot_dropdown.send_key(new_plot)

    # wait until box plot renders, at this point all 3 should be done
    @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'box-rendered')}
    box_rendered = @driver.execute_script("return $('#expression-plots').data('box-rendered')")
    assert box_rendered, "box plot did not finish rendering, expected true but found #{box_rendered}"
    scatter_rendered = @driver.execute_script("return $('#expression-plots').data('scatter-rendered')")
    assert scatter_rendered, "scatter plot did not finish rendering, expected true but found #{scatter_rendered}"
    reference_rendered = @driver.execute_script("return $('#expression-plots').data('reference-rendered')")
    assert reference_rendered, "reference plot did not finish rendering, expected true but found #{reference_rendered}"

    gene_sets = @driver.find_element(:id, 'gene_set')
    opts = gene_sets.find_elements(:tag_name, 'option').delete_if {|o| o.text == 'Please select a gene list'}
    list = opts.sample
    list.click
    assert element_present?(@driver, :id, 'expression-plots'), 'could not find box/scatter divs'
    sleep(1)

    # wait until violin plot renders, at this point all 3 should be done
    @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'box-rendered')}
    violin_rendered = @driver.execute_script("return $('#expression-plots').data('box-rendered')")
    assert violin_rendered, "violin plot did not finish rendering, expected true but found #{violin_rendered}"
    scatter_rendered = @driver.execute_script("return $('#expression-plots').data('scatter-rendered')")
    assert scatter_rendered, "scatter plot did not finish rendering, expected true but found #{scatter_rendered}"
    reference_rendered = @driver.execute_script("return $('#expression-plots').data('reference-rendered')")
    assert reference_rendered, "reference plot did not finish rendering, expected true but found #{reference_rendered}"

    scroll_to(@driver, :top)
    open_ui_tab(@driver, 'study-download')

    download_button = @driver.find_element(:class, 'cluster-file')
    download_button.click

    sleep(5)
    filename = 'cluster_2d_example.txt'
    basename = 'cluster_2d_example'
    # make sure file was actually downloaded
    file_exists = Dir.entries($download_dir).select {|f| f =~ /#{basename}/}.size >= 1 || File.exists?(File.join($download_dir, filename))
    assert file_exists, "did not find downloaded file: #{filename} in #{Dir.entries($download_dir).join(', ')}"

    # open the file
    file = File.open(File.join($download_dir, filename))
    first_line = file.readline.split("\t").map(&:strip)
    %w[NAME X Y Sub-Group].each do |header|
      assert (first_line.include?header), "Original cluster's rows are absent, rows: #{first_line}, is missing #{header}"
    end
    assert (first_line.include?"user-#{$random_seed}"), "New annotation's rows are absent, rows: #{first_line}, missing: user-#{$random_seed}"

    # delete matching files
    Dir.glob("#{$download_dir}/*").select {|f| /#{basename}/.match(f)}.map {|f| File.delete(f)}

    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name} successful!"
  end

  #check user annotation deletion
  test 'front-end: user-annotation: deletion' do
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name}"

    # login
    login_path = @base_url + '/users/sign_in'
    @driver.get login_path
    wait_until_page_loads(@driver, login_path)
    login(@driver, $test_email, $test_email_password)

    # load annotation panel
    annot_path = @base_url + '/user_annotations'
    @driver.get annot_path

    delete_btn = @driver.find_element(:class, "user-#{$random_seed}-exp-delete")
    delete_btn.click
    accept_alert(@driver)
    close_modal(@driver, 'message_modal')

    #check new names
    first_row = @driver.find_element(:id, 'annotations').find_element(:tag_name, 'tbody').find_element(:tag_name, 'tr').find_element(:tag_name, 'td')
    unless first_row['class'] == 'dataTables_empty'
      #If you dont't have any annotations, they were all deleted
      new_names = @driver.find_elements(:class, 'annotation-name').map{|x| x.text }
      #assert new name saved correctly
      assert !(new_names.include? "user-#{$random_seed}-exp"), "Deletion failed, expected no 'user-#{$random_seed}-exp' but found it"
    end

    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name} successful!"
  end

end
