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
end
