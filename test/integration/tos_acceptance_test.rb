require "integration_test_helper"

class TosAcceptanceTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @test_user = User.find_by(email: 'testing.user@gmail.com')
    auth_as_user(@test_user)
  end

  test 'should record user tos action' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"
    sign_in @test_user
    # first log in and validate that the user is redirected to the ToS page
    get site_path
    follow_redirect!
    assert path == accept_tos_path(@test_user.id), "Did not redirect to terms of service path, current path is #{path}"
    # first deny ToS and validate that user gets signed out
    post record_tos_action_path(id: @test_user.id, tos: {action: 'deny'})
    follow_redirect!
    user_accepted = TosAcceptance.accepted?(@test_user)
    assert !user_accepted, "Did not record user denial, acceptance shows: #{user_accepted}"
    assert controller.current_user.nil?, "Did not sign out user, current_user is #{controller.current_user}"
    # now accept ToS
    sign_in @test_user
    post record_tos_action_path(id: @test_user.id, tos: {action: 'accept'})
    follow_redirect!
    user_accepted = TosAcceptance.accepted?(@test_user)
    assert user_accepted, "Did not record user acceptance, acceptance shows: #{user_accepted}"
    assert controller.current_user == @test_user, "Did not preserve sign in, current user is not #{@test_user.email}"
    # now get another page and validate that redirect is no longer being enforced
    get site_path
    assert path == site_path, "Redirect still being enforced, expected path to be #{site_path} but found #{path}"
    puts "#{File.basename(__FILE__)}: #{self.method_name} completed!"
  end
end

