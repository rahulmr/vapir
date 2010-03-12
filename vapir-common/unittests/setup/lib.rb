$myDir.sub!( %r{/cygdrive/(\w)/}, '\1:/' ) # convert from cygwin to dos

require 'vapir-common/options'
Vapir.options_file = $suite_options_file = $myDir + '/options.yml' 
require 'unittests/setup/options'
unit_options = Vapir::UnitTest::Options.new.execute
require 'unittests/setup/browser'
require 'unittests/setup/filter'
require 'unittests/setup/capture_io_helper'
require 'unittests/setup/watir-unittest'

failure_tag = "fails_on_#{Vapir.options[:browser]}".to_sym
case unit_options[:coverage]
  when 'regression'
  Vapir::UnitTest.filter_out_tests_tagged failure_tag
  when 'known failures'
  Vapir::UnitTest.filter_out do |test|
    !(test.tagged? failure_tag)
  end
end

