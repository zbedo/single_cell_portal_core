require "test_helper"

class RequestUtilsTest < ActiveSupport::TestCase

  test 'should sanitize page inputs' do
    assert_equal(2, RequestUtils.sanitize_page_param(2))
    assert_equal(5, RequestUtils.sanitize_page_param('5'))
    assert_equal(1, RequestUtils.sanitize_page_param(nil))
    assert_equal(1, RequestUtils.sanitize_page_param('foobar'))
    assert_equal(1, RequestUtils.sanitize_page_param('undefined'))
    assert_equal(1, RequestUtils.sanitize_page_param('0'))
    assert_equal(1, RequestUtils.sanitize_page_param('-6'))
  end

  test 'should exclude NaN from minmax for numeric arrays' do
    source = [Float::NAN, 1.0, 100.0]
    numeric_array = 1000.times.map {source.sample}
    min, max = RequestUtils.get_minmax(numeric_array)
    assert_equal 1.0, min, "Did not get expected min of 1.0: #{min}"
    assert_equal 100.0, min, "Did not get expected max of 100.0: #{max}"
  end
end
