require 'test_helper'

class TestRandom < ActiveSupport::TestCase
  include Challah

  should "be able to provide a random string from ActiveSupport" do
    result = Random.token(10)

    assert_not_nil result
    assert_equal 10, result.size
  end

  should "be able to provide a random string without ActiveSupport" do
    Challah::Random.stubs(:secure_random?).returns(false)
    SecureRandom.expects(:hex).never

    result = Challah::Random.token(10)

    assert_not_nil result
    assert_equal 10, result.size
  end
end
