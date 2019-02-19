require "integration_test_helper"

class AnalysisConfigurationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def setup
    @test_user = User.find_by(email: 'testing.user@gmail.com')
    @analysis_configuration = AnalysisConfiguration.first
    auth_as_user(@test_user)
    sign_in @test_user
  end

  test 'should get index page' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    get analysis_configurations_path
    assert_response 200, 'Did not successfully load analysis configurations index page'
    assert_select 'tr.analysis-configuration-entry', 1, 'Did not find any analysis configuration entries'
    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test 'should get detail page' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"
    get analysis_configuration_path(@analysis_configuration)
    assert_response 200, "Did not successfully load detail page for #{@analysis_configuration.identifier}"
    assert_select 'div#analysis-parameters', 1, 'Did not find analysis parameters div'
    assert_select 'form.analysis-parameter-form', 2, 'Did not find correct number of analysis parameter entries'
    assert_select 'form.input-analysis-parameter', 1, 'Did not find correct number of inputs'
    assert_select 'form.output-analysis-parameter', 1, 'Did not find correct number of outputs'
    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test 'should create and delete analysis configuration' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"
    analysis_configuration_params = {
        analysis_configuration: {
            namespace: 'unity-benchmark-test',
            name: 'test-analysis',
            snapshot: 1,
            user_id: @test_user.id,
            configuration_namespace: 'unity-benchmark-test',
            configuration_name: 'test-analysis',
            configuration_snapshot: 2
        }
    }
    post analysis_configurations_path, params: analysis_configuration_params
    follow_redirect!
    assert_response 200, 'Did not redirect successfully after creating analysis configuration'
    get analysis_configurations_path
    new_config = AnalysisConfiguration.find_by(namespace: 'unity-benchmark-test', name: 'test-analysis', snapshot: 1)
    assert new_config.present?, 'Analysis configuration did not persist'
    assert new_config.analysis_parameters.size == 2,
           "Did not find correct number of parameters, expected 2 but found #{new_config.analysis_parameters.size}"
    delete analysis_configuration_path(new_config)
    follow_redirect!
    assert_response 200, 'Did not successfully redirect after deleting analysis configuration'
    assert AnalysisConfiguration.count == 1,
           "Did not successfully delete analysis configuration, found #{AnalysisConfiguration.count} instead of 1"
    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end
end
