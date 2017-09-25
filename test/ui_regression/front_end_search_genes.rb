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
    @test_data_path = File.expand_path(File.join('test', 'test_data')) + '/'
    @accept_next_alert = true

    puts "\n"
  end

  # called on completion of every test (whether it passes or fails)
  def teardown
    @driver.quit
  end

  test 'front-end: search-genes: single' do
    puts "Test method: #{self.method_name}"

    path = @base_url + "/study/test-study-#{$random_seed}"
    @driver.get(path)
    wait_until_page_loads(@driver, path)
    open_ui_tab(@driver, 'study-visualize')

    # perform negative search first to test redirect
    bad_gene = 'foo'
    search_box = @driver.find_element(:id, 'search_genes')
    search_box.send_key(bad_gene)
    search_genes = @driver.find_element(:id, 'perform-gene-search')
    search_genes.click
    wait_for_render(@driver, :id, 'message_modal')
    alert_text = @driver.find_element(:id, 'alert-content')
    assert alert_text.text == 'No matches found for: foo.', 'did not redirect and display alert correctly'
    close_modal(@driver, 'message_modal')

    # load random gene to search
    gene = @genes.sample
    search_box = @driver.find_element(:id, 'search_genes')
    search_box.send_key(gene)
    search_genes = @driver.find_element(:id, 'perform-gene-search')
    search_genes.click
    assert element_present?(@driver, :id, 'box-controls'), 'could not find expression violin plot'
    assert element_present?(@driver, :id, 'scatter-plots'), 'could not find expression scatter plots'

    # confirm queried gene is the one returned
    queried_gene = @driver.find_element(:class, 'queried-gene')
    assert queried_gene.text == gene, "did not load the correct gene, expected #{gene} but found #{queried_gene.text}"

    # testing loading all annotation types
    @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'box-rendered')}
    annotations = @driver.find_element(:id, 'annotation').find_elements(:tag_name, 'option')
    annotations_values = annotations.map{|x| x['value']}
    annotations_values.each do |annotation|
      @driver.find_element(:id, 'annotation').send_key annotation
      type = annotation.split('--')[1]
      # puts "loading annotation: #{annotation}"
      if type == 'group'
        # if looking at box, switch back to violin
        @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'box-rendered')}
        plot_dropdown = @driver.find_element(:id, 'plot_type')
        plot_ops = plot_dropdown.find_elements(:tag_name, 'option')

        is_box_plot = plot_ops.select {|opt| opt.selected?}.sample.text == 'Box Plot'
        if is_box_plot
          new_plot = plot_ops.select {|opt| !opt.selected?}.sample.text
          plot_dropdown.send_key(new_plot)
        end
        # wait until violin plot renders, at this point all 3 should be done

        @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'box-rendered')}
        violin_rendered = @driver.execute_script("return $('#expression-plots').data('box-rendered')")
        assert violin_rendered, "violin plot did not finish rendering, expected true but found #{violin_rendered}"
        scatter_rendered = @driver.execute_script("return $('#expression-plots').data('scatter-rendered')")
        assert scatter_rendered, "scatter plot did not finish rendering, expected true but found #{scatter_rendered}"
        reference_rendered = @driver.execute_script("return $('#expression-plots').data('reference-rendered')")
        assert reference_rendered, "reference plot did not finish rendering, expected true but found #{reference_rendered}"

        # select new kernel
        kernel_dropdown = @driver.find_element(:id, 'kernel_type')
        kernel_ops = kernel_dropdown.find_elements(:tag_name, 'option')
        new_kernel = kernel_ops.select {|opt| !opt.selected?}.sample.text
        kernel_dropdown.send_key(new_kernel)

        # wait until violin plot renders, at this point all 3 should be done
        @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'box-rendered')}
        violin_rendered = @driver.execute_script("return $('#expression-plots').data('box-rendered')")
        assert violin_rendered, "violin plot kernel did not finish rendering, expected true but found #{violin_rendered}"
        scatter_rendered = @driver.execute_script("return $('#expression-plots').data('scatter-rendered')")
        assert scatter_rendered, "scatter plot did not finish rendering, expected true but found #{scatter_rendered}"
        reference_rendered = @driver.execute_script("return $('#expression-plots').data('reference-rendered')")
        assert reference_rendered, "reference plot did not finish rendering, expected true but found #{reference_rendered}"

        # select new bandwidth
        bandwidth_dropdown = @driver.find_element(:id, 'band_type')
        band_ops = bandwidth_dropdown.find_elements(:tag_name, 'option')
        new_band = band_ops.select {|opt| !opt.selected?}.sample.text
        bandwidth_dropdown.send_key(new_band)

        # wait until violin plot renders, at this point all 3 should be done
        @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'box-rendered')}
        violin_rendered = @driver.execute_script("return $('#expression-plots').data('box-rendered')")
        assert violin_rendered, "violin plot bandwidth did not finish rendering, expected true but found #{violin_rendered}"
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

      else
        @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'box-rendered')}
        box_rendered = @driver.execute_script("return $('#expression-plots').data('box-rendered')")
        assert box_rendered, "box plot did not finish rendering, expected true but found #{box_rendered}"
        scatter_rendered = @driver.execute_script("return $('#expression-plots').data('scatter-rendered')")
        assert scatter_rendered, "scatter plot did not finish rendering, expected true but found #{scatter_rendered}"
        reference_rendered = @driver.execute_script("return $('#expression-plots').data('reference-rendered')")
        assert reference_rendered, "reference plot did not finish rendering, expected true but found #{reference_rendered}"
      end

    end
    # now test private study
    login_path = @base_url + '/users/sign_in'
    @driver.get login_path
    wait_until_page_loads(@driver, login_path)
    login(@driver, $test_email, $test_email_password)
    private_study_path = @base_url + "/study/private-study-#{$random_seed}"
    @driver.get private_study_path
    wait_until_page_loads(@driver, private_study_path)
    open_ui_tab(@driver, 'study-visualize')

    new_gene = @genes.sample
    search_box = @driver.find_element(:id, 'search_genes')
    search_box.send_key(new_gene)
    search_genes = @driver.find_element(:id, 'perform-gene-search')
    search_genes.click
    assert element_present?(@driver, :id, 'box-controls'), 'could not find expression boxplot'
    assert element_present?(@driver, :id, 'scatter-plots'), 'could not find expression scatter plots'

    # confirm queried gene is the one returned
    new_queried_gene = @driver.find_element(:class, 'queried-gene')
    assert new_queried_gene.text == new_gene, "did not load the correct gene, expected #{new_gene} but found #{new_queried_gene.text}"

    # wait until box plot renders, at this point all 3 should be done
    @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'box-rendered')}
    private_violin_rendered = @driver.execute_script("return $('#expression-plots').data('box-rendered')")
    assert private_violin_rendered, "private violin plot did not finish rendering, expected true but found #{private_violin_rendered}"
    private_scatter_rendered = @driver.execute_script("return $('#expression-plots').data('scatter-rendered')")
    assert private_scatter_rendered, "private scatter plot did not finish rendering, expected true but found #{private_scatter_rendered}"
    private_reference_rendered = @driver.execute_script("return $('#expression-plots').data('reference-rendered')")
    assert private_reference_rendered, "private reference plot did not finish rendering, expected true but found #{private_reference_rendered}"

    # select new kernel
    private_kernel_dropdown = @driver.find_element(:id, 'kernel_type')
    private_kernel_ops = private_kernel_dropdown.find_elements(:tag_name, 'option')
    private_new_kernel = private_kernel_ops.select {|opt| !opt.selected?}.sample.text
    private_kernel_dropdown.send_key(private_new_kernel)

    # wait until violin plot renders, at this point all 3 should be done
    @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'box-rendered')}
    private_violin_rendered = @driver.execute_script("return $('#expression-plots').data('box-rendered')")
    assert private_violin_rendered, "private violin plot kernel did not finish rendering, expected true but found #{private_violin_rendered}"
    scatter_rendered = @driver.execute_script("return $('#expression-plots').data('scatter-rendered')")
    assert scatter_rendered, "private scatter plot did not finish rendering, expected true but found #{scatter_rendered}"
    reference_rendered = @driver.execute_script("return $('#expression-plots').data('reference-rendered')")
    assert reference_rendered, "private reference plot did not finish rendering, expected true but found #{reference_rendered}"

    # select new bandwidth
    private_bandwidth_dropdown = @driver.find_element(:id, 'band_type')
    private_band_ops = private_bandwidth_dropdown.find_elements(:tag_name, 'option')
    private_new_band = private_band_ops.select {|opt| !opt.selected?}.sample.text
    private_bandwidth_dropdown.send_key(private_new_band)

    # wait until violin plot renders, at this point all 3 should be done
    @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'box-rendered')}
    private_violin_rendered = @driver.execute_script("return $('#expression-plots').data('box-rendered')")
    assert private_violin_rendered, "private violin plot bandwidth did not finish rendering, expected true but found #{private_violin_rendered}"
    scatter_rendered = @driver.execute_script("return $('#expression-plots').data('scatter-rendered')")
    assert scatter_rendered, "private scatter plot did not finish rendering, expected true but found #{scatter_rendered}"
    reference_rendered = @driver.execute_script("return $('#expression-plots').data('reference-rendered')")
    assert reference_rendered, "private reference plot did not finish rendering, expected true but found #{reference_rendered}"

    # change to box plot
    private_plot_dropdown = @driver.find_element(:id, 'plot_type')
    private_plot_ops = private_plot_dropdown.find_elements(:tag_name, 'option')
    private_new_plot = private_plot_ops.select {|opt| !opt.selected?}.sample.text
    private_plot_dropdown.send_key(private_new_plot)

    # wait until box plot renders, at this point all 3 should be done
    @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'box-rendered')}
    private_box_rendered = @driver.execute_script("return $('#expression-plots').data('box-rendered')")
    assert private_box_rendered, "private box plot did not finish rendering, expected true but found #{private_box_rendered}"
    scatter_rendered = @driver.execute_script("return $('#expression-plots').data('scatter-rendered')")
    assert scatter_rendered, "private scatter plot did not finish rendering, expected true but found #{scatter_rendered}"
    reference_rendered = @driver.execute_script("return $('#expression-plots').data('reference-rendered')")
    assert reference_rendered, "private reference plot did not finish rendering, expected true but found #{reference_rendered}"

    puts "Test method: #{self.method_name} successful!"
  end

  test 'front-end: search-genes: multiple consensus' do
    puts "Test method: #{self.method_name}"

    path = @base_url + "/study/test-study-#{$random_seed}"
    @driver.get(path)
    wait_until_page_loads(@driver, path)
    open_ui_tab(@driver, 'study-visualize')

    # load random genes to search, take between 2-5, adding in bad gene to test error handling
    genes = @genes.shuffle.take(rand(2..5))
    search_box = @driver.find_element(:id, 'search_genes')
    search_box.send_keys(genes.join(' ') + ' foo')
    consensus = @driver.find_element(:id, 'search_consensus')
    # select a random consensus measurement
    opts = consensus.find_elements(:tag_name, 'option').delete_if {|o| o.text == 'None'}
    selected_consensus = opts.sample
    selected_consensus_value = selected_consensus['value']
    selected_consensus.click
    search_genes = @driver.find_element(:id, 'perform-gene-search')
    search_genes.click
    assert element_present?(@driver, :id, 'box-controls'), 'could not find expression boxplot'
    assert element_present?(@driver, :id, 'scatter-plots'), 'could not find expression scatter plots'
    assert element_present?(@driver, :id, 'missing-genes'), 'did not find missing genes list'

    # confirm queried genes and selected consensus are correct
    queried_genes = @driver.find_elements(:class, 'queried-gene').map(&:text)
    assert genes.sort == queried_genes.sort, "found incorrect genes, expected #{genes.sort} but found #{queried_genes.sort}"
    queried_consensus = @driver.find_element(:id, 'selected-consensus')
    assert selected_consensus_value == queried_consensus.text, "did not load correct consensus metric, expected #{selected_consensus_value} but found #{queried_consensus.text}"

    # testing loading all annotation types
    @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'box-rendered')}
    annotations = @driver.find_element(:id, 'annotation').find_elements(:tag_name, 'option')
    annotations_values = annotations.map{|x| x['value']}
    annotations_values.each do |annotation|
      @driver.find_element(:id, 'annotation').send_key annotation
      type = annotation.split('--')[1]
      # puts "loading annotation: #{annotation}"
      if type == 'group'
        # if looking at box, switch back to violin
        @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'box-rendered')}
        plot_dropdown = @driver.find_element(:id, 'plot_type')
        plot_ops = plot_dropdown.find_elements(:tag_name, 'option')

        is_box_plot = plot_ops.select {|opt| opt.selected?}.sample.text == 'Box Plot'
        if is_box_plot
          new_plot = plot_ops.select {|opt| !opt.selected?}.sample.text
          plot_dropdown.send_key(new_plot)
        end
        # wait until violin plot renders, at this point all 3 should be done

        @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'box-rendered')}
        violin_rendered = @driver.execute_script("return $('#expression-plots').data('box-rendered')")
        assert violin_rendered, "violin plot did not finish rendering, expected true but found #{violin_rendered}"
        scatter_rendered = @driver.execute_script("return $('#expression-plots').data('scatter-rendered')")
        assert scatter_rendered, "scatter plot did not finish rendering, expected true but found #{scatter_rendered}"
        reference_rendered = @driver.execute_script("return $('#expression-plots').data('reference-rendered')")
        assert reference_rendered, "reference plot did not finish rendering, expected true but found #{reference_rendered}"

        # select new kernel
        kernel_dropdown = @driver.find_element(:id, 'kernel_type')
        kernel_ops = kernel_dropdown.find_elements(:tag_name, 'option')
        new_kernel = kernel_ops.select {|opt| !opt.selected?}.sample.text
        kernel_dropdown.send_key(new_kernel)

        # wait until violin plot renders, at this point all 3 should be done
        @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'box-rendered')}
        violin_rendered = @driver.execute_script("return $('#expression-plots').data('box-rendered')")
        assert violin_rendered, "violin plot kernel did not finish rendering, expected true but found #{violin_rendered}"
        scatter_rendered = @driver.execute_script("return $('#expression-plots').data('scatter-rendered')")
        assert scatter_rendered, "scatter plot did not finish rendering, expected true but found #{scatter_rendered}"
        reference_rendered = @driver.execute_script("return $('#expression-plots').data('reference-rendered')")
        assert reference_rendered, "reference plot did not finish rendering, expected true but found #{reference_rendered}"

        # select new bandwidth
        bandwidth_dropdown = @driver.find_element(:id, 'band_type')
        band_ops = bandwidth_dropdown.find_elements(:tag_name, 'option')
        new_band = band_ops.select {|opt| !opt.selected?}.sample.text
        bandwidth_dropdown.send_key(new_band)

        # wait until violin plot renders, at this point all 3 should be done
        @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'box-rendered')}
        violin_rendered = @driver.execute_script("return $('#expression-plots').data('box-rendered')")
        assert violin_rendered, "violin plot bandwidth did not finish rendering, expected true but found #{violin_rendered}"
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

      else
        @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'box-rendered')}
        box_rendered = @driver.execute_script("return $('#expression-plots').data('box-rendered')")
        assert box_rendered, "box plot did not finish rendering, expected true but found #{box_rendered}"
        scatter_rendered = @driver.execute_script("return $('#expression-plots').data('scatter-rendered')")
        assert scatter_rendered, "scatter plot did not finish rendering, expected true but found #{scatter_rendered}"
        reference_rendered = @driver.execute_script("return $('#expression-plots').data('reference-rendered')")
        assert reference_rendered, "reference plot did not finish rendering, expected true but found #{reference_rendered}"
      end

    end
    # now test private study
    login_path = @base_url + '/users/sign_in'
    @driver.get login_path
    wait_until_page_loads(@driver, login_path)
    login(@driver, $test_email, $test_email_password)
    private_study_path = @base_url + "/study/private-study-#{$random_seed}"
    @driver.get private_study_path
    wait_until_page_loads(@driver, private_study_path)
    open_ui_tab(@driver, 'study-visualize')


    new_genes = @genes.shuffle.take(rand(2..5))
    search_box = @driver.find_element(:id, 'search_genes')
    search_box.send_keys(new_genes.join(' '))
    new_consensus = @driver.find_element(:id, 'search_consensus')
    # select a random consensus measurement
    new_opts = new_consensus.find_elements(:tag_name, 'option').delete_if {|o| o.text == 'None'}
    new_selected_consensus = new_opts.sample
    new_selected_consensus_value = new_selected_consensus['value']
    new_selected_consensus.click
    search_genes = @driver.find_element(:id, 'perform-gene-search')
    search_genes.click
    assert element_present?(@driver, :id, 'box-controls'), 'could not find expression boxplot'
    assert element_present?(@driver, :id, 'scatter-plots'), 'could not find expression scatter plots'

    # confirm queried genes are correct
    new_queried_genes = @driver.find_elements(:class, 'queried-gene').map(&:text)
    assert new_genes.sort == new_queried_genes.sort, "found incorrect genes, expected #{new_genes.sort} but found #{new_queried_genes.sort}"
    new_queried_consensus = @driver.find_element(:id, 'selected-consensus')
    assert new_selected_consensus_value == new_queried_consensus.text, "did not load correct consensus metric, expected #{new_selected_consensus_value} but found #{new_queried_consensus.text}"

    # wait until box plot renders, at this point all 3 should be done
    @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'box-rendered')}
    private_violin_rendered = @driver.execute_script("return $('#expression-plots').data('box-rendered')")
    assert private_violin_rendered, "private violin plot did not finish rendering, expected true but found #{private_violin_rendered}"
    private_scatter_rendered = @driver.execute_script("return $('#expression-plots').data('scatter-rendered')")
    assert private_scatter_rendered, "private scatter plot did not finish rendering, expected true but found #{private_scatter_rendered}"
    private_reference_rendered = @driver.execute_script("return $('#expression-plots').data('reference-rendered')")
    assert private_reference_rendered, "private reference plot did not finish rendering, expected true but found #{private_reference_rendered}"

    # select new kernel
    private_kernel_dropdown = @driver.find_element(:id, 'kernel_type')
    private_kernel_ops = private_kernel_dropdown.find_elements(:tag_name, 'option')
    private_new_kernel = private_kernel_ops.select {|opt| !opt.selected?}.sample.text
    private_kernel_dropdown.send_key(private_new_kernel)

    # wait until violin plot renders, at this point all 3 should be done
    @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'box-rendered')}
    private_violin_rendered = @driver.execute_script("return $('#expression-plots').data('box-rendered')")
    assert private_violin_rendered, "private violin plot kernel did not finish rendering, expected true but found #{private_violin_rendered}"
    scatter_rendered = @driver.execute_script("return $('#expression-plots').data('scatter-rendered')")
    assert scatter_rendered, "private scatter plot did not finish rendering, expected true but found #{scatter_rendered}"
    reference_rendered = @driver.execute_script("return $('#expression-plots').data('reference-rendered')")
    assert reference_rendered, "private reference plot did not finish rendering, expected true but found #{reference_rendered}"

    # select new bandwidth
    private_bandwidth_dropdown = @driver.find_element(:id, 'band_type')
    private_band_ops = private_bandwidth_dropdown.find_elements(:tag_name, 'option')
    private_new_band = private_band_ops.select {|opt| !opt.selected?}.sample.text
    private_bandwidth_dropdown.send_key(private_new_band)

    # wait until violin plot renders, at this point all 3 should be done
    @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'box-rendered')}
    private_violin_rendered = @driver.execute_script("return $('#expression-plots').data('box-rendered')")
    assert private_violin_rendered, "private violin plot bandwidth did not finish rendering, expected true but found #{private_violin_rendered}"
    scatter_rendered = @driver.execute_script("return $('#expression-plots').data('scatter-rendered')")
    assert scatter_rendered, "private scatter plot did not finish rendering, expected true but found #{scatter_rendered}"
    reference_rendered = @driver.execute_script("return $('#expression-plots').data('reference-rendered')")
    assert reference_rendered, "private reference plot did not finish rendering, expected true but found #{reference_rendered}"

    # change to box plot
    private_plot_dropdown = @driver.find_element(:id, 'plot_type')
    private_plot_ops = private_plot_dropdown.find_elements(:tag_name, 'option')
    private_new_plot = private_plot_ops.select {|opt| !opt.selected?}.sample.text
    private_plot_dropdown.send_key(private_new_plot)

    # wait until box plot renders, at this point all 3 should be done
    @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'box-rendered')}
    private_box_rendered = @driver.execute_script("return $('#expression-plots').data('box-rendered')")
    assert private_box_rendered, "private box plot did not finish rendering, expected true but found #{private_box_rendered}"
    scatter_rendered = @driver.execute_script("return $('#expression-plots').data('scatter-rendered')")
    assert scatter_rendered, "private scatter plot did not finish rendering, expected true but found #{scatter_rendered}"
    reference_rendered = @driver.execute_script("return $('#expression-plots').data('reference-rendered')")
    assert reference_rendered, "private reference plot did not finish rendering, expected true but found #{reference_rendered}"

    puts "Test method: #{self.method_name} successful!"
  end

  test 'front-end: search-genes: multiple heatmap' do
    puts "Test method: #{self.method_name}"

    path = @base_url + "/study/test-study-#{$random_seed}"
    @driver.get(path)
    wait_until_page_loads(@driver, path)
    open_ui_tab(@driver, 'study-visualize')

    # load random genes to search, take between 2-5
    genes = @genes.shuffle.take(rand(2..5))
    search_box = @driver.find_element(:id, 'search_genes')
    search_box.send_keys(genes.join(' '))
    search_genes = @driver.find_element(:id, 'perform-gene-search')
    search_genes.click

    assert element_present?(@driver, :id, 'plots'), 'could not find expression heatmap'

    annotations = @driver.find_element(:id, 'annotation').find_elements(:tag_name, 'option')
    annotations_values = annotations.map{|x| x['value']}
    annotations_values.each do |annotation|
      @driver.find_element(:id, 'annotation').send_key annotation
      @wait.until {wait_for_morpheus_render(@driver, '#heatmap-plot', 'morpheus')}
      heatmap_drawn = @driver.execute_script("return $('#heatmap-plot').data('morpheus').heatmap !== undefined;")
      assert heatmap_drawn, "heatmap plot encountered error, expected true but found #{heatmap_drawn}"
    end

    heatmap_drawn = @driver.execute_script("return $('#heatmap-plot').data('morpheus').heatmap !== undefined;")
    assert heatmap_drawn, "heatmap plot encountered error, expected true but found #{heatmap_drawn}"

    # confirm queried genes are correct
    queried_genes = @driver.find_elements(:class, 'queried-gene').map(&:text)
    assert genes.sort == queried_genes.sort, "found incorrect genes, expected #{genes.sort} but found #{queried_genes.sort}"

    # resize heatmap
    heatmap_size = @driver.find_element(:id, 'heatmap_size')
    heatmap_size.send_key(1000)
    @wait.until {wait_for_morpheus_render(@driver, '#heatmap-plot', 'morpheus')}

    resize_heatmap_drawn = @driver.execute_script("return $('#heatmap-plot').data('morpheus').heatmap !== undefined;")
    assert resize_heatmap_drawn, "heatmap plot encountered error, expected true but found #{resize_heatmap_drawn}"

    # toggle fullscreen
    fullscreen = @driver.find_element(:id, 'view-fullscreen')
    fullscreen.click
    @wait.until {wait_for_morpheus_render(@driver, '#heatmap-plot', 'morpheus')}
    fullscreen_heatmap_drawn = @driver.execute_script("return $('#heatmap-plot').data('morpheus').heatmap !== undefined;")
    assert fullscreen_heatmap_drawn, "heatmap plot encountered error, expected true but found #{fullscreen_heatmap_drawn}"
    search_opts_visible = element_visible?(@driver, :id, 'search-options-panel')
    assert !search_opts_visible, "fullscreen mode did not launch correctly, expected search options visibility == false but found #{!search_opts_visible}"

    # now test private study
    login_path = @base_url + '/users/sign_in'
    @driver.get login_path
    wait_until_page_loads(@driver, login_path)
    login(@driver, $test_email, $test_email_password)
    private_study_path = @base_url + "/study/private-study-#{$random_seed}"
    @driver.get private_study_path
    wait_until_page_loads(@driver, private_study_path)
    open_ui_tab(@driver, 'study-visualize')

    new_genes = @genes.shuffle.take(rand(2..5))
    search_box = @driver.find_element(:id, 'search_genes')
    search_box.send_keys(new_genes.join(' '))
    search_genes = @driver.find_element(:id, 'perform-gene-search')
    search_genes.click
    assert element_present?(@driver, :id, 'plots'), 'could not find expression heatmap'
    @wait.until {wait_for_morpheus_render(@driver, '#heatmap-plot', 'morpheus')}
    private_rendered = @driver.execute_script("return $('#heatmap-plot').data('rendered')")
    assert private_rendered, "private heatmap plot did not finish rendering, expected true but found #{private_rendered}"
    private_heatmap_drawn = @driver.execute_script("return $('#heatmap-plot').data('morpheus').heatmap !== undefined;")
    assert private_heatmap_drawn, "heatmap plot encountered error, expected true but found #{private_heatmap_drawn}"

    # confirm queried genes are correct
    new_queried_genes = @driver.find_elements(:class, 'queried-gene').map(&:text)
    assert new_genes.sort == new_queried_genes.sort, "found incorrect genes, expected #{new_genes.sort} but found #{new_queried_genes.sort}"

    puts "Test method: #{self.method_name} successful!"
  end

  test 'front-end: search-genes: multiple upload file' do
    puts "Test method: #{self.method_name}"

    path = @base_url + "/study/test-study-#{$random_seed}"
    @driver.get(path)
    wait_until_page_loads(@driver, path)
    open_ui_tab(@driver, 'study-visualize')

    # upload gene list
    search_upload = @driver.find_element(:id, 'search_upload')
    search_upload.send_keys(@test_data_path + 'search_genes.txt')
    search_genes = @driver.find_element(:id, 'perform-gene-search')
    search_genes.click

    assert element_present?(@driver, :id, 'plots'), 'could not find expression heatmap'
    @wait.until {wait_for_morpheus_render(@driver, '#heatmap-plot', 'morpheus')}
    heatmap_drawn = @driver.execute_script("return $('#heatmap-plot').data('morpheus').heatmap !== undefined;")
    assert heatmap_drawn, "heatmap plot encountered error, expected true but found #{heatmap_drawn}"

    # now test private study
    login_path = @base_url + '/users/sign_in'
    @driver.get login_path
    wait_until_page_loads(@driver, login_path)
    login(@driver, $test_email, $test_email_password)
    private_study_path = @base_url + "/study/private-study-#{$random_seed}"
    @driver.get private_study_path
    wait_until_page_loads(@driver, private_study_path)
    open_ui_tab(@driver, 'study-visualize')

    search_upload = @driver.find_element(:id, 'search_upload')
    search_upload.send_keys(@test_data_path + 'search_genes.txt')
    search_genes = @driver.find_element(:id, 'perform-gene-search')
    search_genes.click
    assert element_present?(@driver, :id, 'plots'), 'could not find expression heatmap'
    @wait.until {wait_for_morpheus_render(@driver, '#heatmap-plot', 'morpheus')}
    private_heatmap_drawn = @driver.execute_script("return $('#heatmap-plot').data('morpheus').heatmap !== undefined;")
    assert private_heatmap_drawn, "heatmap plot encountered error, expected true but found #{private_heatmap_drawn}"

    puts "Test method: #{self.method_name} successful!"
  end

  test 'front-end: marker-gene: heatmap' do
    puts "Test method: #{self.method_name}"

    path = @base_url + "/study/test-study-#{$random_seed}"
    @driver.get(path)
    wait_until_page_loads(@driver, path)
    open_ui_tab(@driver, 'study-visualize')

    expression_list = @driver.find_element(:id, 'expression')
    opts = expression_list.find_elements(:tag_name, 'option').delete_if {|o| o.text == 'Please select a gene list'}
    list = opts.sample
    list.click
    assert element_present?(@driver, :id, 'heatmap-plot'), 'could not find heatmap plot'

    # wait for heatmap to render
    @wait.until {wait_for_morpheus_render(@driver, '#heatmap-plot', 'morpheus')}
    heatmap_drawn = @driver.execute_script("return $('#heatmap-plot').data('morpheus').heatmap !== undefined;")
    assert heatmap_drawn, "heatmap plot encountered error, expected true but found #{heatmap_drawn}"

    # now test private study
    login_path = @base_url + '/users/sign_in'
    @driver.get login_path
    wait_until_page_loads(@driver, login_path)
    login(@driver, $test_email, $test_email_password)
    private_study_path = @base_url + "/study/private-study-#{$random_seed}"
    @driver.get private_study_path
    wait_until_page_loads(@driver, private_study_path)
    open_ui_tab(@driver, 'study-visualize')

    private_expression_list = @driver.find_element(:id, 'expression')
    opts = private_expression_list.find_elements(:tag_name, 'option').delete_if {|o| o.text == 'Please select a gene list'}
    list = opts.sample
    list.click
    assert element_present?(@driver, :id, 'heatmap-plot'), 'could not find heatmap plot'

    # wait for heatmap to render
    @wait.until {wait_for_morpheus_render(@driver, '#heatmap-plot', 'morpheus')}
    private_heatmap_drawn = @driver.execute_script("return $('#heatmap-plot').data('morpheus').heatmap !== undefined;")
    assert private_heatmap_drawn, "heatmap plot encountered error, expected true but found #{private_heatmap_drawn}"

    puts "Test method: #{self.method_name} successful!"
  end

  test 'front-end: marker-gene: box/scatter' do
    puts "Test method: #{self.method_name}"

    path = @base_url + "/study/test-study-#{$random_seed}"
    @driver.get(path)
    wait_until_page_loads(@driver, path)
    open_ui_tab(@driver, 'study-visualize')

    gene_sets = @driver.find_element(:id, 'gene_set')
    opts = gene_sets.find_elements(:tag_name, 'option').delete_if {|o| o.text == 'Please select a gene list'}
    list = opts.sample
    list.click
    assert element_present?(@driver, :id, 'expression-plots'), 'could not find box/scatter divs'

    # testing loading all annotation types
    @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'box-rendered')}
    annotations = @driver.find_element(:id, 'annotation').find_elements(:tag_name, 'option')
    annotations_values = annotations.map{|x| x['value']}
    annotations_values.each do |annotation|
      @driver.find_element(:id, 'annotation').send_key annotation
      type = annotation.split('--')[1]
      # puts "loading annotation: #{annotation}"
      if type == 'group'
        # if looking at box, switch back to violin
        @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'box-rendered')}
        plot_dropdown = @driver.find_element(:id, 'plot_type')
        plot_ops = plot_dropdown.find_elements(:tag_name, 'option')

        is_box_plot = plot_ops.select {|opt| opt.selected?}.sample.text == 'Box Plot'
        if is_box_plot
          new_plot = plot_ops.select {|opt| !opt.selected?}.sample.text
          plot_dropdown.send_key(new_plot)
        end
        # wait until violin plot renders, at this point all 3 should be done

        @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'box-rendered')}
        violin_rendered = @driver.execute_script("return $('#expression-plots').data('box-rendered')")
        assert violin_rendered, "violin plot did not finish rendering, expected true but found #{violin_rendered}"
        scatter_rendered = @driver.execute_script("return $('#expression-plots').data('scatter-rendered')")
        assert scatter_rendered, "scatter plot did not finish rendering, expected true but found #{scatter_rendered}"
        reference_rendered = @driver.execute_script("return $('#expression-plots').data('reference-rendered')")
        assert reference_rendered, "reference plot did not finish rendering, expected true but found #{reference_rendered}"

        # select new kernel
        kernel_dropdown = @driver.find_element(:id, 'kernel_type')
        kernel_ops = kernel_dropdown.find_elements(:tag_name, 'option')
        new_kernel = kernel_ops.select {|opt| !opt.selected?}.sample.text
        kernel_dropdown.send_key(new_kernel)

        # wait until violin plot renders, at this point all 3 should be done
        @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'box-rendered')}
        violin_rendered = @driver.execute_script("return $('#expression-plots').data('box-rendered')")
        assert violin_rendered, "violin plot kernel did not finish rendering, expected true but found #{violin_rendered}"
        scatter_rendered = @driver.execute_script("return $('#expression-plots').data('scatter-rendered')")
        assert scatter_rendered, "scatter plot did not finish rendering, expected true but found #{scatter_rendered}"
        reference_rendered = @driver.execute_script("return $('#expression-plots').data('reference-rendered')")
        assert reference_rendered, "reference plot did not finish rendering, expected true but found #{reference_rendered}"

        # select new bandwidth
        bandwidth_dropdown = @driver.find_element(:id, 'band_type')
        band_ops = bandwidth_dropdown.find_elements(:tag_name, 'option')
        new_band = band_ops.select {|opt| !opt.selected?}.sample.text
        bandwidth_dropdown.send_key(new_band)

        # wait until violin plot renders, at this point all 3 should be done
        @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'box-rendered')}
        violin_rendered = @driver.execute_script("return $('#expression-plots').data('box-rendered')")
        assert violin_rendered, "violin plot bandwidth did not finish rendering, expected true but found #{violin_rendered}"
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

      else
        @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'box-rendered')}
        box_rendered = @driver.execute_script("return $('#expression-plots').data('box-rendered')")
        assert box_rendered, "box plot did not finish rendering, expected true but found #{box_rendered}"
        scatter_rendered = @driver.execute_script("return $('#expression-plots').data('scatter-rendered')")
        assert scatter_rendered, "scatter plot did not finish rendering, expected true but found #{scatter_rendered}"
        reference_rendered = @driver.execute_script("return $('#expression-plots').data('reference-rendered')")
        assert reference_rendered, "reference plot did not finish rendering, expected true but found #{reference_rendered}"
      end

    end

    # now test private study
    login_path = @base_url + '/users/sign_in'
    @driver.get login_path
    wait_until_page_loads(@driver, login_path)
    login(@driver, $test_email, $test_email_password)
    private_study_path = @base_url + "/study/private-study-#{$random_seed}"
    @driver.get private_study_path
    wait_until_page_loads(@driver, private_study_path)
    open_ui_tab(@driver, 'study-visualize')

    private_gene_sets = @driver.find_element(:id, 'gene_set')
    opts = private_gene_sets.find_elements(:tag_name, 'option').delete_if {|o| o.text == 'Please select a gene list'}
    list = opts.sample
    list.click
    assert element_present?(@driver, :id, 'expression-plots'), 'could not find box/scatter divs'

    # wait until box plot renders, at this point all 3 should be done
    @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'box-rendered')}
    private_violin_rendered = @driver.execute_script("return $('#expression-plots').data('box-rendered')")
    assert private_violin_rendered, "private violin plot did not finish rendering, expected true but found #{private_violin_rendered}"
    private_scatter_rendered = @driver.execute_script("return $('#expression-plots').data('scatter-rendered')")
    assert private_scatter_rendered, "private scatter plot did not finish rendering, expected true but found #{private_scatter_rendered}"
    private_reference_rendered = @driver.execute_script("return $('#expression-plots').data('reference-rendered')")
    assert private_reference_rendered, "private reference plot did not finish rendering, expected true but found #{private_reference_rendered}"

    # select new kernel
    private_kernel_dropdown = @driver.find_element(:id, 'kernel_type')
    private_kernel_ops = private_kernel_dropdown.find_elements(:tag_name, 'option')
    private_new_kernel = private_kernel_ops.select {|opt| !opt.selected?}.sample.text
    private_kernel_dropdown.send_key(private_new_kernel)

    # wait until violin plot renders, at this point all 3 should be done
    @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'box-rendered')}
    private_violin_rendered = @driver.execute_script("return $('#expression-plots').data('box-rendered')")
    assert private_violin_rendered, "private violin plot kernel did not finish rendering, expected true but found #{private_violin_rendered}"
    scatter_rendered = @driver.execute_script("return $('#expression-plots').data('scatter-rendered')")
    assert scatter_rendered, "private scatter plot did not finish rendering, expected true but found #{scatter_rendered}"
    reference_rendered = @driver.execute_script("return $('#expression-plots').data('reference-rendered')")
    assert reference_rendered, "private reference plot did not finish rendering, expected true but found #{reference_rendered}"

    # select new bandwidth
    private_bandwidth_dropdown = @driver.find_element(:id, 'band_type')
    private_band_ops = private_bandwidth_dropdown.find_elements(:tag_name, 'option')
    private_new_band = private_band_ops.select {|opt| !opt.selected?}.sample.text
    private_bandwidth_dropdown.send_key(private_new_band)

    # wait until violin plot renders, at this point all 3 should be done
    @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'box-rendered')}
    private_violin_rendered = @driver.execute_script("return $('#expression-plots').data('box-rendered')")
    assert private_violin_rendered, "private violin plot bandwidth did not finish rendering, expected true but found #{private_violin_rendered}"
    scatter_rendered = @driver.execute_script("return $('#expression-plots').data('scatter-rendered')")
    assert scatter_rendered, "private scatter plot did not finish rendering, expected true but found #{scatter_rendered}"
    reference_rendered = @driver.execute_script("return $('#expression-plots').data('reference-rendered')")
    assert reference_rendered, "private reference plot did not finish rendering, expected true but found #{reference_rendered}"

    # change to box plot
    private_plot_dropdown = @driver.find_element(:id, 'plot_type')
    private_plot_ops = private_plot_dropdown.find_elements(:tag_name, 'option')
    private_new_plot = private_plot_ops.select {|opt| !opt.selected?}.sample.text
    private_plot_dropdown.send_key(private_new_plot)

    # wait until box plot renders, at this point all 3 should be done
    @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'box-rendered')}
    private_box_rendered = @driver.execute_script("return $('#expression-plots').data('box-rendered')")
    assert private_box_rendered, "private box plot did not finish rendering, expected true but found #{private_box_rendered}"
    scatter_rendered = @driver.execute_script("return $('#expression-plots').data('scatter-rendered')")
    assert scatter_rendered, "private scatter plot did not finish rendering, expected true but found #{scatter_rendered}"
    reference_rendered = @driver.execute_script("return $('#expression-plots').data('reference-rendered')")
    assert reference_rendered, "private reference plot did not finish rendering, expected true but found #{reference_rendered}"

    puts "Test method: #{self.method_name} successful!"
  end

end
