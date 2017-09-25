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
    @test_data_path = File.expand_path(File.join(File.dirname(__FILE__), 'test_data')) + '/'
    @accept_next_alert = true

    puts "\n"
  end

  # called on completion of every test (whether it passes or fails)
  def teardown
    @driver.quit
  end

  test 'front-end: view: home page' do
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name}"

    @driver.get(@base_url)
    assert element_present?(@driver, :id, 'main-banner'), 'could not find index page title text'
    assert @driver.find_elements(:class, 'panel-primary').size >= 1, 'did not find any studies'
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name} successful!"
  end

  test 'front-end: search' do
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name}"

    @driver.get(@base_url)
    search_box = @driver.find_element(:id, 'search_terms')
    search_box.send_keys("#{$random_seed}")
    submit = @driver.find_element(:id, 'submit-search')
    submit.click
    studies = @driver.find_elements(:class, 'study-panel').size
    assert studies >= 3, 'incorrect number of studies found. expected more than or equal to three but found ' + studies.to_s
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name} successful!"
  end

  test 'front-end: view: study' do
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name}"

    path = @base_url + "/study/test-study-#{$random_seed}"
    @driver.get(path)
    wait_until_page_loads(@driver, path)
    open_ui_tab(@driver, 'study-visualize')

    assert element_present?(@driver, :class, 'study-lead'), 'could not find study title'
    assert element_present?(@driver, :id, 'cluster-plot'), 'could not find study cluster plot'

    # wait until cluster finishes rendering
    @wait.until {wait_for_plotly_render(@driver, '#cluster-plot', 'rendered')}
    rendered = @driver.execute_script("return $('#cluster-plot').data('rendered')")
    assert rendered, "cluster plot did not finish rendering, expected true but found #{rendered}"

    # load subclusters
    clusters = @driver.find_element(:id, 'cluster').find_elements(:tag_name, 'option')
    assert clusters.size == 2, "incorrect number of clusters found, expected 2 but found #{clusters.size}"
    annotations = @driver.find_element(:id, 'annotation').find_elements(:tag_name, 'option')
    assert annotations.size == 5, "incorrect number of annotations found, expected 5 but found #{annotations.size}"
    annotations.select {|opt| opt.text == 'Sub-Cluster'}.first.click

    # wait for render again
    @wait.until {wait_for_plotly_render(@driver, '#cluster-plot', 'rendered')}
    sub_rendered = @driver.execute_script("return $('#cluster-plot').data('rendered')")
    assert sub_rendered, "cluster plot did not finish rendering on change, expected true but found #{sub_rendered}"
    legend = @driver.find_elements(:class, 'traces').size
    assert legend == 6, "incorrect number of traces found in Sub-Cluster, expected 6 - found #{legend}"

    # testing loading all annotation types
    annotations_values = annotations.map{|x| x['value']}
    annotations_values.each do |annotation|
      @driver.find_element(:id, 'annotation').send_key annotation
      @wait.until {wait_for_plotly_render(@driver, '#cluster-plot', 'rendered')}
      cluster_rendered = @driver.execute_script("return $('#cluster-plot').data('rendered')")
      assert cluster_rendered, "cluster plot did not finish rendering on change, expected true but found #{cluster_rendered}"
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

    @wait.until {wait_for_plotly_render(@driver, '#cluster-plot', 'rendered')}
    private_rendered = @driver.execute_script("return $('#cluster-plot').data('rendered')")
    assert private_rendered, "private cluster plot did not finish rendering, expected true but found #{private_rendered}"

    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name} successful!"
  end

  test 'front-end: download: study file' do
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name}"
    login_path = @base_url + '/users/sign_in'
    # downloads require login now
    @driver.get login_path
    wait_until_page_loads(@driver, login_path)
    login(@driver, $test_email, $test_email_password)

    path = @base_url + "/study/test-study-#{$random_seed}"
    @driver.get(path)
    wait_until_page_loads(@driver, path)
    open_ui_tab(@driver, 'study-download')

    files = @driver.find_elements(:class, 'dl-link')
    file_link = files.last
    filename = file_link['download']
    basename = filename.split('.').first
    @wait.until { file_link.displayed? }
    file_link.click
    # give browser 5 seconds to initiate download
    sleep(5)
    # make sure file was actually downloaded
    file_exists = Dir.entries($download_dir).select {|f| f =~ /#{basename}/}.size >= 1 || File.exists?(File.join($download_dir, filename))
    assert file_exists, "did not find downloaded file: #{filename} in #{Dir.entries($download_dir).join(', ')}"

    # delete matching files
    Dir.glob("#{$download_dir}/*").select {|f| /#{basename}/.match(f)}.map {|f| File.delete(f)}

    # now download a file from a private study
    private_path = @base_url + "/study/private-study-#{$random_seed}"
    @driver.get(private_path)
    wait_until_page_loads(@driver, private_path)
    open_ui_tab(@driver, 'study-download')

    private_files = @driver.find_elements(:class, 'dl-link')
    private_file_link = private_files.first
    private_filename = private_file_link['download']
    private_basename = private_filename.split('.').first
    @wait.until { private_file_link.displayed? }
    private_file_link.click
    # give browser 5 seconds to initiate download
    sleep(5)
    # make sure file was actually downloaded
    private_file_exists = Dir.entries($download_dir).select {|f| f =~ /#{private_basename}/}.size >= 1 || File.exists?(File.join($download_dir, private_filename))
    assert private_file_exists, "did not find downloaded file: #{private_filename} in #{Dir.entries($download_dir).join(', ')}"

    # delete matching files
    Dir.glob("#{$download_dir}/*").select {|f| /#{private_basename}/.match(f)}.map {|f| File.delete(f)}

    # logout
    profile = @driver.find_element(:id, 'profile-nav')
    profile.click
    logout = @driver.find_element(:id, 'logout-nav')
    logout.click
    wait_until_page_loads(@driver, @base_url)
    close_modal(@driver, 'message_modal')

    # now login as share user and test downloads
    @driver.get login_path
    wait_until_page_loads(@driver, login_path)
    login_as_other(@driver, $share_email, $share_email_password)

    @driver.get(path)
    wait_until_page_loads(@driver, path)
    open_ui_tab(@driver, 'study-download')

    files = @driver.find_elements(:class, 'dl-link')
    share_file_link = files.first
    share_filename = share_file_link['data-filename']
    share_basename = share_filename.split('.').first
    @wait.until { share_file_link.displayed? }
    share_file_link.click
    # give browser 5 seconds to initiate download
    sleep(5)
    # make sure file was actually downloaded
    share_file_exists = Dir.entries($download_dir).select {|f| f =~ /#{share_basename}/}.size >= 1 || File.exists?(File.join($download_dir, share_filename))
    assert share_file_exists, "did not find downloaded file: #{share_filename} in #{Dir.entries($download_dir).join(', ')}"

    # delete matching files
    Dir.glob("#{$download_dir}/*").select {|f| /#{share_basename}/.match(f)}.map {|f| File.delete(f)}

    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name} successful!"
  end

  test 'front-end: download: privacy restriction' do
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name}"

    login_path = @base_url + '/users/sign_in'
    @driver.get login_path
    wait_until_page_loads(@driver, login_path)
    login(@driver, $share_email, $share_email_password)

    # negative test, should not be able to download private files from study without access
    non_share_public_link = @base_url + "/data/public/private-study-#{$random_seed}/README.txt"
    non_share_private_link = @base_url + "/data/private/private-study-#{$random_seed}/README.txt"

    # try public rout
    @driver.get non_share_public_link
    public_alert_text = @driver.find_element(:id, 'alert-content').text
    assert public_alert_text == 'You do not have permission to view the requested page.',
           "did not properly redirect, expected 'You do not have permission to view the requested page.' but got #{public_alert_text}"

    # try private route
    @driver.get non_share_private_link
    wait_for_render(@driver, :id, 'message_modal')
    private_alert_text = @driver.find_element(:id, 'alert-content').text
    assert private_alert_text == 'You do not have permission to perform that action.',
           "did not properly redirect, expected 'You do not have permission to view the requested page.' but got #{private_alert_text}"

    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name} successful!"
  end

  # These are unit tests in actuality, but are put in UI test because of docker issues
  test 'front-end: validation: kernel density and bandwidth functions' do
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name}"
    #load website
    path = @base_url
    @driver.get(path)

    #known array with known median and quartile values
    test_array = [1,2,3,4,5]

    #calculate median, min, max and quartiles with simple statistics
    quartile = @driver.execute_script("return ss.quantile(#{test_array}, [0.25, 0.75])")
    median = @driver.execute_script("return ss.median(#{test_array})")

    min = @driver.execute_script("return getMinOfArray(#{test_array})")
    max = @driver.execute_script("return getMaxOfArray(#{test_array})")

    # puts 'Testing basic violin plot math functions (quartile, median, min, max)'

    #Median should be 3, quartiles should be 2 and 4, max should be 5 and min should be 1
    assert (quartile[0] == 2 and quartile[1] == 4), 'Quartiles are incorrect: '  + quartile[0].to_s +  ' ' + quartile[1].to_s
    assert median == 3, 'Median is incorrect: ' + median.to_s
    assert min == test_array.min, 'Min is incorrect: '  + min.to_s
    assert max == test_array.max, 'Max is incorrect: ' + max.to_s

    # puts 'Testing higher level violin plot math functions (isOutlier, cutOutliers)'

    #Array with known outliers
    outlier_test_array = [-2.6, 2, 3, 4, 5, 9.6]

    #-2.6 should be an outlier
    is_outlier = @driver.execute_script("return isOutlier(#{outlier_test_array[0]}, ss.quantile(#{outlier_test_array}, [0.25]), ss.quantile(#{outlier_test_array}, 0.75) )")
    assert is_outlier, 'Outlier incorrectly not identified ' + outlier_test_array[0].to_s

    #9.6 should be an outlier
    is_outlier = @driver.execute_script("return isOutlier(#{outlier_test_array[5]}, ss.quantile(#{outlier_test_array}, [0.25]), ss.quantile(#{outlier_test_array}, 0.75))")
    assert is_outlier, 'Outlier incorrectly not identified ' + outlier_test_array[5].to_s

    #2 should not be an outlier
    is_outlier = @driver.execute_script("return isOutlier(#{outlier_test_array[1]}, ss.quantile(#{outlier_test_array}, [0.25]), ss.quantile(#{outlier_test_array}, 0.75) )")
    assert !is_outlier, 'Outlier incorrectly not identified ' + outlier_test_array[1].to_s

    #5 should not be and outlier
    is_outlier = @driver.execute_script("return isOutlier(#{outlier_test_array[4]}, ss.quantile(#{outlier_test_array}, [0.25]), ss.quantile(#{outlier_test_array}, 0.75))")
    assert !is_outlier, 'Outlier incorrectly not identified ' + outlier_test_array[4].to_s

    #[-2.6,9.6] should be the outliers and the non outliers should be an array of the remaining numbers
    cut_outliers = @driver.execute_script("return cutOutliers(#{outlier_test_array}, ss.quantile(#{outlier_test_array}, [0.25]), ss.quantile(#{outlier_test_array}, 0.75) )")
    assert (cut_outliers[1] == outlier_test_array[1..4] and cut_outliers[0] == [outlier_test_array[5], outlier_test_array[0]]), "Cut outlier incorrect: " + cut_outliers.to_s

    # puts 'Testing highest level math (Kernel Distrbutions)'

    # Python KDE stats only has the seven following functions that match what I have found in JavaScript

    # Testing array. Prime numbers from 0 to 200, there are 46 of them
    kernel_test_array = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97, 101, 103, 107, 109, 113, 127, 131, 137, 139, 149, 151, 157, 163, 167, 173, 179, 181, 191, 193, 197, 199]
    # 'Correct' kernel density scores for bandwidth of 1 found with python using given kernel
    correct_gaussian = [0.006458511, 0.006704709, 0.006930598, 0.007137876, 0.007325677, 0.007493380, 0.007640600, 0.007765395, 0.007866591, 0.007948254, 0.008011220, 0.008056486, 0.008085195, 0.008097190, 0.008094063, 0.008079507, 0.008054997, 0.008021980, 0.007981867, 0.007935508, 0.007884712, 0.007831191, 0.007775831, 0.007719392, 0.007662512, 0.007605775, 0.007549610, 0.007494102, 0.007439251, 0.007384972, 0.007331100, 0.007277341, 0.007223212, 0.007168332, 0.007112321, 0.007054804, 0.006995414, 0.006933322, 0.006868407, 0.006800656, 0.006729964, 0.006656295, 0.006579689, 0.006499781, 0.006417373, 0.006333001, 0.006247130, 0.006160288, 0.006073060, 0.005986391, 0.005901149, 0.005818017, 0.005737680, 0.005660796, 0.005587986, 0.005521125, 0.005459697, 0.005403935, 0.005354035, 0.005310096, 0.005272153, 0.005241391, 0.005215990, 0.005195542, 0.005179576, 0.005167573, 0.005159043, 0.005153719, 0.005150272, 0.005148195, 0.005147039, 0.005146420, 0.005146032, 0.005145642, 0.005145223, 0.005144887, 0.005144833, 0.005145338, 0.005146855, 0.005150204, 0.005155697, 0.005163818, 0.005175027, 0.005189754, 0.005208731, 0.005232706, 0.005261083, 0.005293823, 0.005330777, 0.005371676, 0.005416408, 0.005464253, 0.005513915, 0.005564550, 0.005615250, 0.005665050, 0.005712526, 0.005756092, 0.005795032, 0.005828404, 0.005855330, 0.005875007, 0.005885486, 0.005886195, 0.005877750, 0.005859974, 0.005832824, 0.005796389, 0.005749557, 0.005693563, 0.005629906, 0.005559324, 0.005482642, 0.005400763, 0.005314198, 0.005224866, 0.005134150, 0.005043127, 0.004952863, 0.004864400, 0.004779599, 0.004699329, 0.004624223, 0.004555018, 0.004492369, 0.004436849, 0.004390707, 0.004352999, 0.004323594, 0.004302562, 0.004289882, 0.004285444, 0.004290800, 0.004303732, 0.004323604, 0.004349863, 0.004381892, 0.004419015, 0.004461274, 0.004506556, 0.004554040, 0.004602904, 0.004652336, 0.004701519, 0.004749184, 0.004794769, 0.004837739, 0.004877644, 0.004914130, 0.004946798, 0.004974849, 0.004999204, 0.005020085, 0.005037808, 0.005052771, 0.005065368, 0.005076192, 0.005086308, 0.005096331, 0.005106854, 0.005118437, 0.005131756, 0.005147592, 0.005165873, 0.005186704, 0.005210078, 0.005235877, 0.005264020, 0.005294000, 0.005324895, 0.005356059, 0.005386791, 0.005416352, 0.005443623, 0.005467395, 0.005487267, 0.005502614, 0.005512890, 0.005517635, 0.005515662, 0.005506797, 0.005491790, 0.005470785, 0.005444031, 0.005411875, 0.005374134, 0.005331887, 0.005286271, 0.005237941, 0.005187557, 0.005135772, 0.005083230, 0.005030777, 0.004978903, 0.004927967, 0.004878250, 0.004829951, 0.004783476, 0.004738592, 0.004695064, 0.004652704, 0.004611278, 0.004570516, 0.004530086, 0.004489503, 0.004448456, 0.004406668, 0.004363890, 0.004319908, 0.004274198, 0.004226930, 0.004178133, 0.004127851, 0.004076178, 0.004023255, 0.003969125, 0.003914399, 0.003859427, 0.003804588, 0.003750299, 0.003697033, 0.003645860, 0.003597095, 0.003551323, 0.003509150, 0.003471201, 0.003438299, 0.003412449, 0.003393210, 0.003381210, 0.003377055, 0.003381319, 0.003395026, 0.003420270, 0.003455536, 0.003501052, 0.003556954, 0.003623284, 0.003700685, 0.003789968, 0.003888784, 0.003996593, 0.004112753, 0.004236532, 0.004367589, 0.004504956, 0.004646475, 0.004791066, 0.004937624, 0.005085031, 0.005231962, 0.005376721, 0.005518343, 0.005655847, 0.005788308, 0.005914859, 0.006033708, 0.006143816, 0.006245485, 0.006338210, 0.006421545, 0.006495100, 0.006556999, 0.006607250, 0.006646755, 0.006675343, 0.006692865, 0.006699190, 0.006692309, 0.006672956, 0.006642072, 0.006599599, 0.006545500, 0.006479753, 0.006400226, 0.006308339, 0.006205035, 0.006090492, 0.005964940, 0.005828671, 0.005680088, 0.005521449, 0.005353893, 0.005178116, 0.004994894, 0.004805079, 0.004608735, 0.004408365, 0.004205311, 0.004000794, 0.003796082, 0.003592481, 0.003392475, 0.003197246, 0.003008108, 0.002826383, 0.002653365, 0.002490376, 0.002341774, 0.002206092, 0.002084244, 0.001977039, 0.001885178, 0.001809668, 0.001754406, 0.001715866, 0.001694045, 0.001688800, 0.001699855, 0.001727470, 0.001773267, 0.001833064, 0.001905907, 0.001990752, 0.002086467, 0.002192342, 0.002307525, 0.002428836, 0.002554924, 0.002684450, 0.002816102, 0.002948529, 0.003079951, 0.003209217, 0.003335404, 0.003457689, 0.003575357, 0.003687211, 0.003792342, 0.003891336, 0.003984063, 0.004070474, 0.004150597, 0.004223799, 0.004290241, 0.004350936, 0.004406057, 0.004455757, 0.004500159, 0.004538618, 0.004571254, 0.004598559, 0.004620374, 0.004636493, 0.004646669, 0.004649556, 0.004645117, 0.004633689, 0.004615054, 0.004589063, 0.004555638, 0.004513538, 0.004463858, 0.004407624, 0.004345440, 0.004278052, 0.004206342, 0.004131069, 0.004054394, 0.003977845, 0.003902825, 0.003830752, 0.003763050, 0.003702807, 0.003650661, 0.003607420, 0.003573970, 0.003551019, 0.003539089, 0.003541133, 0.003554551, 0.003578687, 0.003612899, 0.003656360, 0.003708065, 0.003768047, 0.003832764, 0.003900730, 0.003970441, 0.004040397, 0.004109064, 0.004173898, 0.004234040, 0.004288483, 0.004336376, 0.004377030, 0.004409621, 0.004432374, 0.004447067, 0.004453949, 0.004453409, 0.004445966, 0.004431963, 0.004411786, 0.004387558, 0.004360194, 0.004330617, 0.004299742, 0.004268527, 0.004238240, 0.004209644, 0.004183362, 0.004159934, 0.004139811, 0.004123728, 0.004112228, 0.004104749, 0.004101230, 0.004101526, 0.004105416, 0.004112913, 0.004123483, 0.004136189, 0.004150517, 0.004165933, 0.004181891, 0.004197733, 0.004212671, 0.004226245, 0.004238031, 0.004247656, 0.004254804, 0.004258775, 0.004259530, 0.004257355, 0.004252333, 0.004244617, 0.004234434, 0.004221815, 0.004207526, 0.004192219, 0.004176401, 0.004160602, 0.004145368, 0.004131626, 0.004119968, 0.004110791, 0.004104526, 0.004101552, 0.004102188, 0.004107531, 0.004117076, 0.004130604, 0.004147981, 0.004168974, 0.004193262, 0.004220858, 0.004250398, 0.004281098, 0.004312181, 0.004342811, 0.004372110, 0.004398220, 0.004420522, 0.004438160, 0.004450319, 0.004456257, 0.004455221, 0.004444834, 0.004426568, 0.004400399, 0.004366476, 0.004325129, 0.004276684, 0.004221132, 0.004161141, 0.004097981, 0.004033050, 0.003967851, 0.003904166, 0.003844910, 0.003791456, 0.003745408, 0.003708280, 0.003681479, 0.003667195, 0.003668345, 0.003683375, 0.003712662, 0.003756347, 0.003814336, 0.003887447, 0.003975606, 0.004075393, 0.004185505, 0.004304476, 0.004430689, 0.004562687, 0.004697753, 0.004833136, 0.004966854, 0.005096942, 0.005221466, 0.005337262, 0.005441706, 0.005534243, 0.005613460, 0.005678080, 0.005726968, 0.005756528, 0.005766355, 0.005757846, 0.005730731, 0.005684900, 0.005620398, 0.005534493, 0.005429287, 0.005307138, 0.005168893, 0.005015526, 0.004848127, 0.004665931]
    correct_epanechnikov =  [0.00847826,  0.01030435,  0.01082609,  0.00834783,  0.00717391,  0.00717391,  0.00717391,  0.00717391,  0.00443478,  0.006,  0.006,  0.00443478,  0.00717391,  0.00717391,  0.00443478, 0.00326087,  0.006,  0.006,  0.00443478,  0.00717391,  0.006,  0.00443478,  0.00443478, 0.00326087,  0.00443478,  0.00717391,  0.00717391,  0.00717391,  0.00717391,  0.00443478, 0.00443478,  0.00443478,  0.006,  0.006,  0.006,  0.006,  0.00326087,  0.00443478,  0.00443478,  0.00326087,  0.006,  0.006,  0.006,  0.00717391,  0.00717391,  0.006]

    # Script kernel density scores
    test_gaussian = @driver.execute_script("return kernelDensityEstimator(kernelGaussian(5), genRes(46, 2, 199))(#{kernel_test_array})").map{|v| v[1]}

    test_epanechnikov = @driver.execute_script("return kernelDensityEstimator(kernelEpanechnikov(5.0), #{kernel_test_array})(#{kernel_test_array})").map{|v| v[1]}

    # Testing if script kernel density scores match 'correct' kernel density scores within 0.1% accuracy
    assert compare_within_rounding_error(0.01, correct_gaussian, test_gaussian), "Gaussian failure: " + correct_gaussian.to_s + 'Test'+ test_gaussian.to_s
    assert compare_within_rounding_error(0.02, correct_epanechnikov, test_epanechnikov), "Epanechnikov failure: " + correct_epanechnikov.to_s + "\nTest\n" + test_epanechnikov.to_s

    # Testing if kernel density scores identify as incorrect if compared against known incorrect data within 0.1% accuracy.
    # Known incorrect data is correct data with first element increased by 0.1
    incorrect_gaussian = correct_gaussian.map{|x| x * 1.1}
    incorrect_epanechnikov = correct_epanechnikov.map{|x| x * 1.1}

    # Test if not incorrect
    assert !compare_within_rounding_error(0.01, incorrect_gaussian, test_gaussian), "Gaussian Incorrect failure: " + incorrect_gaussian.to_s + test_gaussian.to_s
    assert !compare_within_rounding_error(0.01, incorrect_epanechnikov, test_epanechnikov), "Epanechnikov Incorrect failure: " + incorrect_epanechnikov.to_s + test_epanechnikov.to_s
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name} successful!"
  end

  # tests that form values for loaded clusters & annotations are being persisted when switching between different views and using 'back' button in search box
  test 'front-end: validation: cluster and annotation persistence' do
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name}"

    path = @base_url + "/study/test-study-#{$random_seed}"
    @driver.get(path)
    wait_until_page_loads(@driver, path)
    open_ui_tab(@driver, 'study-visualize')

    @wait.until {wait_for_plotly_render(@driver, '#cluster-plot', 'rendered')}
    clusters = @driver.find_element(:id, 'cluster').find_elements(:tag_name, 'option')
    cluster = clusters.last
    cluster_name = cluster['text']
    cluster.click

    # wait for render to complete
    @wait.until {wait_for_plotly_render(@driver, '#cluster-plot', 'rendered')}
    cluster_rendered = @driver.execute_script("return $('#cluster-plot').data('rendered')")
    assert cluster_rendered, "cluster plot did not finish rendering on cluster change, expected true but found #{cluster_rendered}"

    # select an annotation and wait for render
    annotations = @driver.find_element(:id, 'annotation').find_elements(:tag_name, 'option')
    annotation = annotations.sample
    annotation_value = annotation['value']
    annotation.click
    # puts "Using annotation #{annotation_value}"
    @wait.until {wait_for_plotly_render(@driver, '#cluster-plot', 'rendered')}
    annot_rendered = @driver.execute_script("return $('#cluster-plot').data('rendered')")
    assert annot_rendered, "cluster plot did not finish rendering on annotation change, expected true but found #{annot_rendered}"

    # now search for a gene and make sure values are preserved
    gene = @genes.sample
    search_box = @driver.find_element(:id, 'search_genes')
    search_box.send_key(gene)
    search_genes = @driver.find_element(:id, 'perform-gene-search')
    search_genes.click

    # wait for rendering to complete
    assert element_present?(@driver, :id, 'expression-plots'), 'could not find box/scatter divs'

    @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'box-rendered')}
    violin_rendered = @driver.execute_script("return $('#expression-plots').data('box-rendered')")
    assert violin_rendered, "box plot did not finish rendering, expected true but found #{violin_rendered}"
    scatter_rendered = @driver.execute_script("return $('#expression-plots').data('scatter-rendered')")
    assert scatter_rendered, "scatter plot did not finish rendering, expected true but found #{scatter_rendered}"
    reference_rendered = @driver.execute_script("return $('#expression-plots').data('reference-rendered')")
    assert reference_rendered, "reference plot did not finish rendering, expected true but found #{reference_rendered}"

    # now check values
    loaded_cluster = @driver.find_element(:id, 'cluster')
    loaded_annotation = @driver.find_element(:id, 'annotation')
    assert loaded_cluster['value'] == cluster_name, "did not load correct cluster; expected #{cluster_name} but loaded #{loaded_cluster['value']}"
    assert loaded_annotation['value'] == annotation_value, "did not load correct annotation; expected #{annotation_value} but loaded #{loaded_annotation['value']}"

    # now check the back button in the search box to make sure it preserves values
    back_btn = @driver.find_element(:id, 'clear-gene-search')
    back_btn.click
    @wait.until {wait_for_plotly_render(@driver, '#cluster-plot', 'rendered')}
    sleep(1)
    current_cluster = @driver.find_element(:id, 'cluster')
    current_annotation = @driver.find_element(:id, 'annotation')
    assert current_cluster['value'] == cluster_name, "did not load correct cluster after back button; expected #{cluster_name} but loaded #{current_cluster['value']}"
    assert current_annotation['value'] == annotation_value, "did not load correct annotation after back button; expected #{current_annotation} but loaded #{current_annotation['value']}"

    # now search for multiple genes as a heatmap
    genes = @genes.shuffle.take(rand(2..5))
    search_box = @driver.find_element(:id, 'search_genes')
    search_box.send_keys(genes.join(' '))
    search_genes = @driver.find_element(:id, 'perform-gene-search')
    search_genes.click
    assert element_present?(@driver, :id, 'plots'), 'could not find expression heatmap'
    @wait.until {wait_for_morpheus_render(@driver, '#heatmap-plot', 'morpheus')}

    # click back button in search box
    back_btn = @driver.find_element(:id, 'clear-gene-search')
    back_btn.click
    @wait.until {wait_for_plotly_render(@driver, '#cluster-plot', 'rendered')}

    heatmap_cluster =  @driver.find_element(:id, 'cluster')['value']
    heatmap_annot = @driver.find_element(:id, 'annotation')['value']
    assert heatmap_cluster == cluster_name, "cluster was not preserved correctly from heatmap view, expected #{cluster_name} but found #{heatmap_cluster}"
    assert heatmap_annot == annotation_value, "cluster was not preserved correctly from heatmap view, expected #{annotation_value} but found #{heatmap_annot}"

    # show gene list in scatter mode
    gene_sets = @driver.find_element(:id, 'gene_set')
    opts = gene_sets.find_elements(:tag_name, 'option').delete_if {|o| o.text == 'Please select a gene list'}
    list = opts.sample
    list.click
    assert element_present?(@driver, :id, 'expression-plots'), 'could not find box/scatter divs'
    @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'box-rendered')}

    # click back button in search box
    back_btn = @driver.find_element(:id, 'clear-gene-search')
    back_btn.click
    @wait.until {wait_for_plotly_render(@driver, '#cluster-plot', 'rendered')}

    gene_list_cluster =  @driver.find_element(:id, 'cluster')['value']
    gene_list_annot = @driver.find_element(:id, 'annotation')['value']
    assert gene_list_cluster == cluster_name, "cluster was not preserved correctly from gene list scatter view, expected #{cluster_name} but found #{gene_list_cluster}"
    assert gene_list_annot == annotation_value, "cluster was not preserved correctly from gene list scatter view, expected #{gene_list_annot} but found #{heatmap_annot}"

    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name} successful!"
  end

  # test that camera position is being preserved on cluster/annotation select & rotation
  test 'front-end: validation: camera position on change' do
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name}"

    path = @base_url + "/study/test-study-#{$random_seed}"
    @driver.get(path)
    wait_until_page_loads(@driver, path)
    open_ui_tab(@driver, 'study-visualize')

    assert element_present?(@driver, :class, 'study-lead'), 'could not find study title'
    assert element_present?(@driver, :id, 'cluster-plot'), 'could not find study cluster plot'

    # wait until cluster finishes rendering
    @wait.until {wait_for_plotly_render(@driver, '#cluster-plot', 'rendered')}
    rendered = @driver.execute_script("return $('#cluster-plot').data('rendered')")
    assert rendered, "cluster plot did not finish rendering, expected true but found #{rendered}"

    # get camera data
    camera = @driver.execute_script("return $('#cluster-plot').data('camera');")
    # set new rotation
    camera['eye']['x'] = (Random.rand * 10 - 5).round(4)
    camera['eye']['y'] = (Random.rand * 10 - 5).round(4)
    camera['eye']['z'] = (Random.rand * 10 - 5).round(4)
    # call relayout to trigger update & camera position save
    @driver.execute_script("Plotly.relayout('cluster-plot', {'scene': {'camera' : #{camera.to_json}}});")

    # wait a second for event to fire, then get new camera
    sleep(1)
    new_camera = @driver.execute_script("return $('#cluster-plot').data('camera');")
    assert camera == new_camera['camera'], "camera position did not save correctly, expected #{camera.to_json}, got #{new_camera.to_json}"
    # load annotation
    annotations = @driver.find_element(:id, 'annotation').find_elements(:tag_name, 'option')
    annotations.select {|opt| opt.text == 'Sub-Cluster'}.first.click

    # wait until cluster finishes rendering
    @wait.until {wait_for_plotly_render(@driver, '#cluster-plot', 'rendered')}
    annot_rendered = @driver.execute_script("return $('#cluster-plot').data('rendered')")
    assert annot_rendered, "cluster plot did not finish rendering on annotation change, expected true but found #{annot_rendered}"

    # verify camera position was saved
    annot_camera = @driver.execute_script("return $('#cluster-plot').data('camera');")
    assert camera == annot_camera['camera'], "camera position did not save correctly, expected #{camera.to_json}, got #{annot_camera.to_json}"

    # load new cluster
    clusters = @driver.find_element(:id, 'cluster').find_elements(:tag_name, 'option')
    cluster = clusters.last
    cluster.click

    # wait until cluster finishes rendering
    @wait.until {wait_for_plotly_render(@driver, '#cluster-plot', 'rendered')}
    cluster_rendered = @driver.execute_script("return $('#cluster-plot').data('rendered')")
    assert cluster_rendered, "cluster plot did not finish rendering on cluster change, expected true but found #{cluster_rendered}"

    # verify camera position was saved
    cluster_camera = @driver.execute_script("return $('#cluster-plot').data('camera');")
    assert camera == cluster_camera['camera'], "camera position did not save correctly, expected #{camera.to_json}, got #{cluster_camera.to_json}"

    # now check gene expression views
    # load random gene to search
    gene = @genes.sample
    search_box = @driver.find_element(:id, 'search_genes')
    search_box.send_key(gene)
    search_genes = @driver.find_element(:id, 'perform-gene-search')
    search_genes.click

    # wait until box plot renders, at this point all 3 should be done
    @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'box-rendered')}

    # get camera data
    scatter_camera = @driver.execute_script("return $('#expression-plots').data('scatter-camera');")
    # set new rotation
    scatter_camera['eye']['x'] = (Random.rand * 10 - 5).round(4)
    scatter_camera['eye']['y'] = (Random.rand * 10 - 5).round(4)
    scatter_camera['eye']['z'] = (Random.rand * 10 - 5).round(4)
    # call relayout to trigger update & camera position save
    @driver.execute_script("Plotly.relayout('scatter-plot', {'scene': {'camera' : #{scatter_camera.to_json}}});")

    # wait a second for event to fire, then get new camera
    sleep(1)
    new_scatter_camera = @driver.execute_script("return $('#expression-plots').data('scatter-camera');")
    assert scatter_camera == new_scatter_camera['camera'], "scatter camera position did not save correctly, expected #{scatter_camera.to_json}, got #{new_scatter_camera.to_json}"

    # load annotation
    exp_annotations = @driver.find_element(:id, 'annotation').find_elements(:tag_name, 'option')
    exp_annotations.select {|opt| opt.text == 'Cluster'}.first.click

    # wait until cluster finishes rendering
    @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'scatter-rendered')}
    annot_rendered = @driver.execute_script("return $('#expression-plots').data('scatter-rendered')")
    assert annot_rendered, "cluster plot did not finish rendering on annotation change, expected true but found #{annot_rendered}"

    # verify camera position was saved
    exp_annot_camera = @driver.execute_script("return $('#expression-plots').data('scatter-camera');")
    assert scatter_camera == exp_annot_camera['camera'], "camera position did not save correctly, expected #{scatter_camera.to_json}, got #{exp_annot_camera.to_json}"

    # load new cluster
    clusters = @driver.find_element(:id, 'cluster').find_elements(:tag_name, 'option')
    cluster = clusters.first
    cluster.click

    # wait until cluster finishes rendering
    @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'scatter-rendered')}
    exp_cluster_rendered = @driver.execute_script("return $('#expression-plots').data('scatter-rendered')")
    assert exp_cluster_rendered, "cluster plot did not finish rendering on cluster change, expected true but found #{exp_cluster_rendered}"

    # verify camera position was saved
    exp_cluster_camera = @driver.execute_script("return $('#expression-plots').data('scatter-camera');")
    assert scatter_camera == exp_cluster_camera['camera'], "camera position did not save correctly, expected #{scatter_camera.to_json}, got #{exp_cluster_camera.to_json}"

    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name} successful!"
  end

  # test that axes are rendering custom domains and labels properly
  test 'front-end: validation: axis domains and labels' do
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name}"

    path = @base_url + "/study/test-study-#{$random_seed}"
    @driver.get(path)
    wait_until_page_loads(@driver, path)
    open_ui_tab(@driver, 'study-visualize')

    assert element_present?(@driver, :class, 'study-lead'), 'could not find study title'
    assert element_present?(@driver, :id, 'cluster-plot'), 'could not find study cluster plot'

    # wait until cluster finishes rendering
    @wait.until {wait_for_plotly_render(@driver, '#cluster-plot', 'rendered')}
    rendered = @driver.execute_script("return $('#cluster-plot').data('rendered')")
    assert rendered, "cluster plot did not finish rendering, expected true but found #{rendered}"

    # get layout object from browser and verify labels & ranges
    layout = @driver.execute_script('return layout;')
    assert layout['scene']['xaxis']['range'] == [-100, 100], "X range was not correctly set, expected [-100, 100] but found #{layout['scene']['xaxis']['range']}"
    assert layout['scene']['yaxis']['range'] == [-75, 75], "Y range was not correctly set, expected [-75, 75] but found #{layout['scene']['xaxis']['range']}"
    assert layout['scene']['zaxis']['range'] == [-125, 125], "Z range was not correctly set, expected [-125, 125] but found #{layout['scene']['xaxis']['range']}"
    assert layout['scene']['xaxis']['title'] == 'X Axis', "X title was not set correctly, expected 'X Axis' but found #{layout['scene']['xaxis']['title']}"
    assert layout['scene']['yaxis']['title'] == 'Y Axis', "Y title was not set correctly, expected 'Y Axis' but found #{layout['scene']['yaxis']['title']}"
    assert layout['scene']['zaxis']['title'] == 'Z Axis', "Z title was not set correctly, expected 'Z Axis' but found #{layout['scene']['zaxis']['title']}"
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name} successful!"
  end

  # test that toggle traces button works
  test 'front-end: validation: toggle traces button' do
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name}"

    path = @base_url + "/study/test-study-#{$random_seed}"
    @driver.get(path)
    wait_until_page_loads(@driver, path)
    open_ui_tab(@driver, 'study-visualize')

    assert element_present?(@driver, :class, 'study-lead'), 'could not find study title'
    assert element_present?(@driver, :id, 'cluster-plot'), 'could not find study cluster plot'

    # wait until cluster finishes rendering
    @wait.until {wait_for_plotly_render(@driver, '#cluster-plot', 'rendered')}
    rendered = @driver.execute_script("return $('#cluster-plot').data('rendered')")
    assert rendered, "cluster plot did not finish rendering, expected true but found #{rendered}"

    # toggle traces off
    toggle = @driver.find_element(:id, 'toggle-traces')
    toggle.click

    # check visiblity
    visible = @driver.execute_script('return data[0].visible')
    assert visible == 'legendonly', "did not toggle trace visibility, expected 'legendonly' but found #{visible}"

    # toggle traces on
    toggle.click

    # check visiblity
    visible = @driver.execute_script('return data[0].visible')
    assert visible == true, "did not toggle trace visibility, expected 'true' but found #{visible}"
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name} successful!"
  end

  # change the default study options and verify they are being preserved across views
  # this is a blend of admin and front-end tests and is run last as has the potential to break previous tests
  test 'front-end: validation: study default options' do
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name}"

    path = @base_url + '/studies'
    @driver.get path
    close_modal(@driver, 'message_modal')
    login(@driver, $test_email, $test_email_password)

    show_study = @driver.find_element(:class, "test-study-#{$random_seed}-show")
    show_study.click

    # change cluster
    options_form = @driver.find_element(:id, 'default-study-options-form')
    cluster_dropdown = options_form.find_element(:id, 'study_default_options_cluster')
    cluster_opts = cluster_dropdown.find_elements(:tag_name, 'option')
    new_cluster = cluster_opts.select {|opt| !opt.selected?}.sample.text
    cluster_dropdown.send_key(new_cluster)

    # wait one second while annotation options update
    sleep(1)

    # change annotation
    annotation_dropdown = options_form.find_element(:id, 'study_default_options_annotation')
    annotation_opts = annotation_dropdown.find_elements(:tag_name, 'option')
    # get value, not text, of dropdown
    new_annot = annotation_opts.select {|opt| !opt.selected?}.sample['value']
    annotation_dropdown.send_key(new_annot)

    # if annotation option is now numeric, pick a color val
    new_color = ''
    color_dropdown = options_form.find_element(:id, 'study_default_options_color_profile')
    if color_dropdown['disabled'] != 'true'
      color_opts = color_dropdown.find_elements(:tag_name, 'option')
      new_color = color_opts.select {|opt| !opt.selected?}.sample.text
      color_dropdown.send_key(new_color)
    end

    # change expression axis label
    expression_label = options_form.find_element(:id, 'study_default_options_expression_label')
    new_exp_label = 'Gene Expression Scores'
    expression_label.send_keys(new_exp_label)

    # save options
    options_form.submit
    close_modal(@driver, 'study-file-notices')

    study_page = @base_url + "/study/test-study-#{$random_seed}"
    @driver.get study_page
    @wait.until {wait_for_plotly_render(@driver, '#cluster-plot', 'rendered')}
    open_ui_tab(@driver, 'study-visualize')

    # assert values have persisted
    loaded_cluster = @driver.find_element(:id, 'cluster')['value']
    loaded_annotation = @driver.find_element(:id, 'annotation')['value']
    assert new_cluster == loaded_cluster, "default cluster incorrect, expected #{new_cluster} but found #{loaded_cluster}"
    assert new_annot == loaded_annotation, "default annotation incorrect, expected #{new_annot} but found #{loaded_annotation}"
    unless new_color.empty?
      loaded_color = @driver.find_element(:id, 'colorscale')['value']
      assert new_color == loaded_color, "default color incorrect, expected #{new_color} but found #{loaded_color}"
    end

    # now check gene expression pages
    gene = @genes.sample
    search_box = @driver.find_element(:id, 'search_genes')
    search_box.send_key(gene)
    search_genes = @driver.find_element(:id, 'perform-gene-search')
    search_genes.click
    @wait.until {wait_for_plotly_render(@driver, '#expression-plots', 'box-rendered')}

    exp_loaded_cluster = @driver.find_element(:id, 'cluster')['value']
    exp_loaded_annotation = @driver.find_element(:id, 'annotation')['value']
    exp_loaded_label = @driver.find_element(:class, 'cbtitle').text
    assert new_cluster == exp_loaded_cluster, "default cluster incorrect, expected #{new_cluster} but found #{exp_loaded_cluster}"
    assert new_annot == exp_loaded_annotation, "default annotation incorrect, expected #{new_annot} but found #{exp_loaded_annotation}"
    assert exp_loaded_label == new_exp_label, "default expression label incorrect, expected #{new_exp_label} but found #{exp_loaded_label}"
    unless new_color.empty?
      exp_loaded_color = @driver.find_element(:id, 'colorscale')['value']
      assert new_color == exp_loaded_color, "default color incorrect, expected #{new_color} but found #{exp_loaded_color}"
    end

    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name} successful!"
  end

  # update a study via the study settings panel
  test 'front-end: validation: edit study settings' do
    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name}"

    login_path = @base_url + '/users/sign_in'
    @driver.get login_path
    wait_until_page_loads(@driver, login_path)
    login(@driver, $test_email, $test_email_password)

    study_page = @base_url + "/study/test-study-#{$random_seed}"
    @driver.get study_page
    wait_until_page_loads(@driver, study_page)

    # update description first
    edit_btn = @driver.find_element(:id, 'edit-study-description')
    edit_btn.click
    wait_for_render(@driver, :id, 'update-study-description')
    # since ckeditor is a seperate DOM, we need to switch to the iframe containing it
    @driver.switch_to.frame(@driver.find_element(:tag_name, 'iframe'))
    description = @driver.find_element(:class, 'cke_editable')
    description.clear
    new_description = "This is the description with a random element: #{SecureRandom.uuid}."
    description.send_keys(new_description)
    @driver.switch_to.default_content
    update_btn = @driver.find_element(:id, 'update-study-description')
    update_btn.click
    wait_for_render(@driver, :id, 'edit-study-description')

    study_description = @driver.find_element(:id, 'study-description-content').text
    assert study_description == new_description, "study description did not update correctly, expected #{new_description} but found #{study_description}"

    # update default options
    close_modal(@driver, 'message_modal')
    open_ui_tab(@driver, 'study-settings')
    options_form = @driver.find_element(:id, 'default-study-options-form')
    cluster_dropdown = options_form.find_element(:id, 'study_default_options_cluster')
    cluster_opts = cluster_dropdown.find_elements(:tag_name, 'option')
    new_cluster = cluster_opts.select {|opt| !opt.selected?}.sample.text
    cluster_dropdown.send_key(new_cluster)

    # wait one second while annotation options update
    sleep(1)

    # change annotation
    annotation_dropdown = options_form.find_element(:id, 'study_default_options_annotation')
    annotation_opts = annotation_dropdown.find_elements(:tag_name, 'option')
    # get value, not text, of dropdown
    new_annot = annotation_opts.select {|opt| !opt.selected?}.sample['value']
    annotation_dropdown.send_key(new_annot)

    # if annotation option is now numeric, pick a color val
    new_color = ''
    color_dropdown = options_form.find_element(:id, 'study_default_options_color_profile')
    if color_dropdown['disabled'] != 'true'
      color_opts = color_dropdown.find_elements(:tag_name, 'option')
      new_color = color_opts.select {|opt| !opt.selected?}.sample.text
      color_dropdown.send_key(new_color)
    end

    # manually set rendered to false to avoid a race condition when checking for updates
    @driver.execute_script("$('#cluster-plot').data('rendered', false);")
    # now save changes
    update_btn = @driver.find_element(:id, 'update-study-settings')
    update_btn.click
    close_modal(@driver, 'message_modal')
    @wait.until {wait_for_plotly_render(@driver, '#cluster-plot', 'rendered')}

    # assert values have persisted
    open_ui_tab(@driver, 'study-visualize')
    loaded_cluster = @driver.find_element(:id, 'cluster')['value']
    loaded_annotation = @driver.find_element(:id, 'annotation')['value']
    assert new_cluster == loaded_cluster, "default cluster incorrect, expected #{new_cluster} but found #{loaded_cluster}"
    assert new_annot == loaded_annotation, "default annotation incorrect, expected #{new_annot} but found #{loaded_annotation}"
    unless new_color.empty?
      loaded_color = @driver.find_element(:id, 'colorscale')['value']
      assert new_color == loaded_color, "default color incorrect, expected #{new_color} but found #{loaded_color}"
    end

    # now test if auth challenge is working properly using test study
    @driver.get(study_page)
    open_new_page(@driver, @base_url)
    profile_nav = @driver.find_element(:id, 'profile-nav')
    profile_nav.click
    logout = @driver.find_element(:id, 'logout-nav')
    logout.click

    # check authentication challenge
    @driver.switch_to.window(@driver.window_handles.first)
    open_ui_tab(@driver, 'study-settings')
    public_dropdown = @driver.find_element(:id, 'study_public')
    public_dropdown.send_keys('Yes')
    update_btn = @driver.find_element(:id, 'update-study-settings')
    update_btn.click
    wait_for_render(@driver, :id, 'message_modal')
    alert_text = @driver.find_element(:id, 'alert-content').text
    assert alert_text == 'Your session has expired. Please log in again to continue.', "incorrect alert text - expected 'Your session has expired.  Please log in again to continue.' but found #{alert_text}"
    close_modal(@driver, 'message_modal')

    puts "#{File.basename(__FILE__)}: Test method: #{self.method_name} successful!"
  end

end
