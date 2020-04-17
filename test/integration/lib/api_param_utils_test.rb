require "test_helper"

class ApiParamUtilsTest < ActiveSupport::TestCase

  test 'should sanitize page inputs' do
    assert_equal(2, ApiParamUtils.sanitize_page_param(2))
    assert_equal(5, ApiParamUtils.sanitize_page_param('5'))
    assert_equal(1, ApiParamUtils.sanitize_page_param(nil))
    assert_equal(1, ApiParamUtils.sanitize_page_param('foobar'))
    assert_equal(1, ApiParamUtils.sanitize_page_param('undefined'))
    assert_equal(1, ApiParamUtils.sanitize_page_param('0'))
    assert_equal(1, ApiParamUtils.sanitize_page_param('-6'))
  end
end
