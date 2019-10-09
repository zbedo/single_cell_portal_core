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
    # first deny ToS and validate that user gets signed out
    post record_tos_action_path(id: @test_user.id, tos: {action: 'deny'})
    follow_redirect!
    user_accepted = TosAcceptance.accepted?(@test_user)
    assert !user_accepted, "Did not record user denial, acceptance shows: #{user_accepted}"
    # now accept ToS
    sign_in @test_user
    post record_tos_action_path(id: @test_user.id, tos: {action: 'accept'})
    follow_redirect!
    user_accepted = TosAcceptance.accepted?(@test_user)
    assert user_accepted, "Did not record user acceptance, acceptance shows: #{user_accepted}"
    puts "#{File.basename(__FILE__)}: #{self.method_name} completed!"
  end
end

