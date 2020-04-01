require "test_helper"

class CellMetadatumTest < ActiveSupport::TestCase

  def setup
    annotation_values = []
    200.times { annotation_values << SecureRandom.uuid }
    @cell_metadatum = CellMetadatum.new(name: 'Group Count Test', annotation_type: 'group', values: annotation_values)
  end

  test 'should not visualize unique group annotations over 100' do
    puts "#{File.basename(__FILE__)}: #{self.method_name}"

    # assert unique group annotations > 100 cannot visualize
    can_visualize = @cell_metadatum.can_visualize?
    assert !can_visualize, "Should not be able to visualize group annotation with more that 100 unique values: #{can_visualize}"

    # check that numeric annotations are still fine
    @cell_metadatum.annotation_type = 'numeric'
    @cell_metadatum.values = []
    can_visualize = @cell_metadatum.can_visualize?
    assert can_visualize, "Should be able to visualize numeric annotations at any level: #{can_visualize}"

    puts "#{File.basename(__FILE__)}: #{self.method_name} successful!"
  end
end
