$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..', '..') unless $SETUP_LOADED

require 'unittests/setup'
require 'vapir-ie/contrib/ie-new-process'
require 'vapir-ie/process'

class TC_New < Test::Unit::TestCase
  
  def setup
    @background_iexplore_processes = Vapir::IE.process_count
    if @background_iexplore_process == 0
      @background = Vapir::IE.new
      assert_equal 1, Vapir::IE.process_count
      @background_iexplore_process = 1
    end
  end

  def teardown
    @background.close if @background
    @new.close if @new
    sleep 1.0 # give it time to close
  end

  def test_new_window_does_not_create_new_process
    @new = Vapir::IE.new_window
    assert_equal @background_iexplore_processes, Vapir::IE.process_count
  end
  
  def test_new_does_not_create_new_process
    @new = Vapir::IE.new
    assert_equal @background_iexplore_processes, Vapir::IE.process_count
  end
  
  def test_start_window_with_no_args_works_like_new_window
    @new = Vapir::IE.start_window
    assert_equal @background_iexplore_processes, Vapir::IE.process_count
  end
  
  def test_start_window_with_url_also_goes_to_that_page
    @new = Vapir::IE.start_window 'http://wtr.rubyforge.org'
    assert_equal @background_iexplore_processes, Vapir::IE.process_count
    assert_equal 'http://wtr.rubyforge.org/', @new.url
  end
  
  tag_method :test_new_process_creates_a_new_process, :fails_on_ie
  def test_new_process_creates_a_new_process
    @new = Vapir::IE.new_process
    assert_equal @background_iexplore_processes + 1, Vapir::IE.process_count
  end
  
  tag_method :test_start_process_with_arg_creates_a_new_process_and_goes_to_that_page, :fails_on_ie
  def test_start_process_with_arg_creates_a_new_process_and_goes_to_that_page
    @new = Vapir::IE.start_process 'http://wtr.rubyforge.org'
    assert_equal @background_iexplore_processes + 1, Vapir::IE.process_count
    assert_equal 'http://wtr.rubyforge.org/', @new.url
  end
end
     