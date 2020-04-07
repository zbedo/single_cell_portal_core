require "test_helper"

class UserTest < ActiveSupport::TestCase
  def setup
    @user = User.first
  end

  test 'should time out token after inactivity' do
    puts "#{File.basename(__FILE__)}: '#{self.method_name}'"

    @user.update_api_last_access_at!
    last_access = @user.api_access_token[:last_access_at]
    now = Time.now.in_time_zone(@user.get_token_timezone(:api_access_token))
    refute @user.api_access_token_timed_out?,
           "API access token should not have timed out, #{last_access} is within #{User.timeout_in} seconds of #{now}"
    # back-date access token last_access_at
    invalid_access = now - 1.hour
    @user.api_access_token[:last_access_at] = invalid_access
    @user.save
    @user.reload
    assert @user.api_access_token_timed_out?,
           "API access token should have timed out, #{invalid_access} is outside #{User.timeout_in} seconds of #{now}"
    # clean up
    @user.update_api_last_access_at!

    puts "#{File.basename(__FILE__)}: '#{self.method_name}' successful!"
  end
end
