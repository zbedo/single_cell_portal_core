require 'rubygems'
require 'test/unit'
require 'selenium-webdriver'

class Test::Unit::TestCase

  # return true/false if element is present in DOM
  # will handle if element doesn't exist or if reference is stale due to race condition
  def element_present?(driver, how, what)
    driver.find_element(how, what)
    true
  rescue Selenium::WebDriver::Error::NoSuchElementError
    false
  rescue Selenium::WebDriver::Error::StaleElementReferenceError
    false
  end

  # return true/false if an element is displayed
  # will handle if element doesn't exist or if reference is stale due to race condition
  def element_visible?(driver, how, what)
    driver.find_element(how, what).displayed?
  rescue Selenium::WebDriver::Error::ElementNotVisibleError
    false
  rescue Selenium::WebDriver::Error::NoSuchElementError
    false
  rescue Selenium::WebDriver::Error::StaleElementReferenceError
    false
  end

  # explicit wait until requested page loads
  def wait_until_page_loads(driver, path)
    wait = Selenium::WebDriver::Wait.new(:timeout => 30)
    # now wait for PAGE_RENDERED to return true
    wait.until { driver.execute_script('return PAGE_RENDERED;') == true }
    # puts "#{path} successfully loaded"
  end

  # method to close a bootstrap modal by id
  def close_modal(driver, id)
    wait = Selenium::WebDriver::Wait.new(:timeout => 30)
    # sanity check in case modal has already opened and closed - if no modal opens in 10 seconds then exit and continue
    i = 0
    while driver.execute_script("return OPEN_MODAL") == ''
      if i == 10
        # puts "Exiting close_modal after 10 seconds - no modal open"
        return true
      else
        sleep(1)
        i += 1
      end
    end
    # need to wait until modal is in the page and has completed opening
    wait.until {driver.execute_script("return OPEN_MODAL") == id}
    modal = driver.find_element(:id, id)
    close_button = modal.find_element(:class, 'close')
    close_button.click
    # wait until OPEN_MODAL has been cleared (will reset on hidden.bs.modal event)
    wait.until {driver.execute_script("return OPEN_MODAL") == ''}
  end

  # wait until element is rendered and visible
  def wait_for_render(driver, how, what)
    wait = Selenium::WebDriver::Wait.new(:timeout => 30)
    wait.until {element_visible?(driver, how, what)}
  end

  # wait until plotly chart has finished rendering, will run for 10 seconds and then raise a timeout error
  def wait_for_plotly_render(driver, plot, data_id)
    # this is necessary to wait for the render variable to set to false initially
    sleep(1)
    i = 1
    i.upto(60) do
      done = driver.execute_script("return $('#{plot}').data('#{data_id}')")
      if !done
        # puts "Waiting for render of #{plot}, currently (#{done}); try ##{i}"
        i += 1
        sleep(1)
        next
      else
        # puts "Rendering of #{plot} complete"
        return true
      end
    end
    raise Selenium::WebDriver::Error::TimeOutError, "Timing out on render check of #{plot}"
  end

  # wait until Morpheus has completed rendering (will happened after data.rendered is true)
  def wait_for_morpheus_render(driver, plot, data_id)
    # first need to wait for data.rendered to be true on plot
    wait_for_plotly_render(driver, plot, 'rendered')
    i = 1
    i.upto(60) do
      done = driver.execute_script("return $('#{plot}').data('#{data_id}').heatmap !== undefined")
      if !done
        # puts "Waiting for render of #{plot}, currently (#{done}); try ##{i}"
        i += 1
        sleep(1)
        next
      else
        # puts "Rendering of #{plot} complete"
        return true
      end
    end
    raise Selenium::WebDriver::Error::TimeOutError, "Timing out on render check of #{plot}"
  end

  # scroll to section of page as needed
  def scroll_to(driver, section)
    case section
      when :bottom
        driver.execute_script('window.scrollBy(0,9999)')
      when :top
        driver.execute_script('window.scrollBy(0,-9999)')
      else
        nil
    end
    sleep(1)
  end

  # helper to log into admin portion of site using supplied credentials
  # Will also approve terms if not accepted yet, waits for redirect back to site, and closes modal
  def login(driver, email, password)
    wait = Selenium::WebDriver::Wait.new(:timeout => 30)
    # determine which password to use
    google_auth = driver.find_element(:id, 'google-auth')
    google_auth.click
    # puts 'logging in as ' + email
    email_field = driver.find_element(:id, 'identifierId')
    email_field.send_key(email)
    sleep(0.5) # this lets the animation complete
    email_next = driver.find_element(:id, 'identifierNext')
    email_next.click
    password_field = driver.find_element(:name, 'password')
    password_field.send_key(password)
    sleep(0.5) # this lets the animation complete
    password_next = driver.find_element(:id, 'passwordNext')
    password_next.click
    # check to make sure if we need to accept terms
    if driver.current_url.include?('https://accounts.google.com/o/oauth2/auth')
      # puts 'approving access'
      approve = @driver.find_element(:id, 'submit_approve_access')
      @clickable = approve['disabled'].nil?
      while @clickable != true
        sleep(1)
        @clickable = driver.find_element(:id, 'submit_approve_access')['disabled'].nil?
      end
      approve.click
      # puts 'access approved'
    end
    # wait for redirect to finish by checking for footer element
    @not_loaded = true
    while @not_loaded == true
      begin
        # we need to return the result of the script to store its value
        loaded = driver.execute_script("return elementVisible('.footer')")
        if loaded == true
          @not_loaded = false
        end
        sleep(1)
      rescue Selenium::WebDriver::Error::UnknownError
        sleep(1)
      end
    end
    wait.until {driver.execute_script("return PAGE_RENDERED;")}
    if element_present?(driver, :id, 'message_modal') && element_visible?(driver,:id, 'message_modal')
      close_modal(driver,'message_modal')
    end
    # puts 'login successful'
  end

  # method to log out of google so that we can log in with a different account
  def login_as_other(driver, email, password)
    # determine which password to use
    driver.get 'https://accounts.google.com/Logout'
    driver.get @base_url + '/users/sign_in'
    google_auth = driver.find_element(:id, 'google-auth')
    sleep(1)
    google_auth.click
    # puts 'logging in as ' + email
    use_new = driver.find_element(:id, 'identifierLink')
    use_new.click
    sleep(0.5)
    email_field = driver.find_element(:id, 'identifierId')
    email_field.send_key(email)
    sleep(0.5) # this lets the animation complete
    email_next = driver.find_element(:id, 'identifierNext')
    email_next.click
    password_field = driver.find_element(:name, 'password')
    password_field.send_key(password)
    sleep(0.5) # this lets the animation complete
    password_next = driver.find_element(:id, 'passwordNext')
    password_next.click
    # check to make sure if we need to accept terms
    if driver.current_url.include?('https://accounts.google.com/o/oauth2/auth')
      # puts 'approving access'
      approve = @driver.find_element(:id, 'submit_approve_access')
      @clickable = approve['disabled'].nil?
      while @clickable != true
        sleep(1)
        @clickable = driver.find_element(:id, 'submit_approve_access')['disabled'].nil?
      end
      approve.click
      # puts 'access approved'
    end
    # wait for redirect to finish by checking for footer element
    @not_loaded = true
    while @not_loaded == true
      begin
        # we need to return the result of the script to store its value
        loaded = driver.execute_script("return elementVisible('.footer')")
        if loaded == true
          @not_loaded = false
        end
        sleep(1)
      rescue Selenium::WebDriver::Error::UnknownError
        sleep(1)
      end
    end
    if element_present?(driver,:id, 'message_modal') && element_visible?(driver,:id, 'message_modal')
      close_modal(driver,'message_modal')
    end
    # puts 'login successful'
  end

  # helper to open tabs in front end, allowing time for tab to become visible
  def open_ui_tab(driver, target)
    wait = Selenium::WebDriver::Wait.new(:timeout => 30)
    tab = driver.find_element(:id, "#{target}-nav")
    tab.click
    wait.until {driver.find_element(:id, target).displayed?}
  end

  # Given two arrays and an error threshold, compares every element of the arrays to corresponding element.
  # Returns false if any elements within arrays are not within the margin of error given.
  # Assumes arrays have same length
  def compare_within_rounding_error(error, a1, a2)
    #Loop control variables
    i = 0
    cont = true
    #Loop through every element in both arrays
    while i < a1.length and cont do
      # Calculates error bar
      max = a2[i] * (1 + error)
      min = a2[i] * (1 - error)
      # Ends loop and returns false if any elements are not within margin of error
      if (a1[i] < min) or (a1[i] > max)
        cont = false
      end
      i += 1
    end
    cont
  end

  # open a new browser tab, switch to it and navigate to a url
  def open_new_page(driver, url)
    driver.execute_script('window.open()')
    driver.switch_to.window(driver.window_handles.last)
    driver.get(url)
  end

  # accept an open alert with error handling
  def accept_alert(driver)
    open = false
    i = 1
    while !open
      if i <= 5
        begin
          driver.switch_to.alert.accept
          open = true
        rescue Selenium::WebDriver::Error::NoSuchAlertError
          sleep 1
          i += 1
        end
      else
        raise Selenium::WebDriver::Error::TimeOutError, "Timing out on closing alert"
      end
    end
  end
end