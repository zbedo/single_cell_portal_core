require "test_helper"

class AnalysisConfigurationTest < ActiveSupport::TestCase
  def setup
    @analysis_configuration = AnalysisConfiguration.first
  end

  test 'load required parameters from methods repo' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    remote_config = @analysis_configuration.methods_repo_settings
    local_config = @analysis_configuration.configuration_settings
    assert local_config === remote_config, "local configs does not match remote configs; diff: #{compare_hashes(remote_config, local_config)}"

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test 'can extract required inputs from configuration' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    remote_config = @analysis_configuration.methods_repo_settings
    inputs = @analysis_configuration.required_inputs
    assert remote_config['inputs'] == inputs, "required inputs do not match; diff: #{compare_hashes(remote_config['inputs'], inputs)}"

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end

  test 'can extract required outputs from configuration' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    remote_config = @analysis_configuration.methods_repo_settings
    outputs = @analysis_configuration.required_outputs
    assert remote_config['outputs'] == outputs, "required inputs do not match; diff: #{compare_hashes(remote_config['outputs'], outputs)}"

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end
end
