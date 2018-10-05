require "integration_test_helper"

class StudyAdminTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @test_user = User.find_by(email: 'testing.user@gmail.com')
    @sharing_user = User.find_by(email: 'sharing.user@gmail.com')
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
                                                                           :provider => 'google_oauth2',
                                                                           :uid => '123545',
                                                                           :email => 'testing.user@gmail.com'
                                                                       })
    sign_in @test_user
    @random_seed = File.open(Rails.root.join('.random_seed')).read.strip
    # delayed_job worker to manually run jobs

  end

  test 'create default testing study' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"
    get studies_path
    assert_response 200, 'Did not get studies path'
    study_params = {
        study: {
            name: "Test Study #{@random_seed}",
            user_id: @test_user.id,
            study_shares_attributes: {
                "0" => {
                    email: @sharing_user.email,
                    permission: 'Edit'
              }
            }
        }
    }
    post studies_path, params: study_params
    follow_redirect!
    assert_response 200, "Did not redirect to upload successfully"
    @new_study = Study.find_by(name: "Test Study #{@random_seed}")
    assert @new_study.present?, "Study did not successfully save"
    @new_study.destroy
    assert Study.find_by(name: "Test Study #{@random_seed}").nil?, "Study did not successfully destroy"
    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end
end
