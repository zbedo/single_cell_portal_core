require "test_helper"

class AnalysisParameterFilterTest < ActiveSupport::TestCase
  def setup
    @analysis_configuration = AnalysisConfiguration.first
  end

  test 'should validate filter values' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    input_parameter = @analysis_configuration.analysis_parameters.inputs.first
    param_filter = input_parameter.analysis_parameter_filters.build

    # validate single filter value
    param_filter.attribute_name = 'file_type'
    refute param_filter.valid?, 'Should not validate filter if value is not set with attribute_name'
    param_filter.value = 'Cluster'
    assert param_filter.valid?, 'Should validate filter with value & attribute_name both present'

    # validate multiple filter values
    param_filter.multiple = true
    refute param_filter.valid?, 'Should not validate filter if multiple_values is blank with multiple = true'
    param_filter.multiple_values = %w(Cluster Metadata)
    assert param_filter.valid?, 'Should validate filter with multiple = true & multiple_values present'

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end
end
