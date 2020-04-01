require "test_helper"

class AnalysisParameterTest < ActiveSupport::TestCase
  def setup
    @analysis_configuration = AnalysisConfiguration.first
  end

  test 'should validate output file types' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    output_param = @analysis_configuration.analysis_parameters.outputs.first
    assert output_param.is_output_file?, "Should have returned true for is_output_file?: #{output_param.is_output_file?}"
    output_param.output_file_type = "Not a file"
    assert !output_param.valid?, "Should not have validated with an invalid file type"

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end
end
