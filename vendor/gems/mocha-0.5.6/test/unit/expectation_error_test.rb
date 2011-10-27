require File.join(File.dirname(__FILE__), "..", "test_helper")
require 'mocha/expectation_error'

class ExpectationErrorTest < Test::Unit::TestCase

  include Mocha

  def test_should_exclude_mocha_locations_from_backtrace
    mocha_lib = "/username/workspace/mocha_wibble/lib/"
    backtrace = [ mocha_lib + 'exclude/me/1', mocha_lib + 'exclude/me/2', '/keep/me', mocha_lib + 'exclude/me/3']
    expectation_error = ExpectationError.new(nil, backtrace, mocha_lib)
    assert_equal ['/keep/me'], expectation_error.backtrace
  end

  def test_should_determine_path_for_mocha_lib_directory
    assert_match Regexp.new("/lib/$"), ExpectationError::LIB_DIRECTORY
  end

  def test_should_set_error_message
    expectation_error = ExpectationError.new('message')
    assert_equal 'message', expectation_error.message
  end

end