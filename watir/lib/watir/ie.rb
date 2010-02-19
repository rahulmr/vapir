=begin
  license
  ---------------------------------------------------------------------------
  Copyright (c) 2004 - 2005, Paul Rogers and Bret Pettichord
  Copyright (c) 2006 - 2008, Bret Pettichord
  All rights reserved.

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions are met:

  1. Redistributions of source code must retain the above copyright notice,
  this list of conditions and the following disclaimer.

  2. Redistributions in binary form must reproduce the above copyright
  notice, this list of conditions and the following disclaimer in the
  documentation and/or other materials provided with the distribution.

  3. Neither the names Paul Rogers, nor Bret Pettichord nor the names of any
  other contributors to this software may be used to endorse or promote
  products derived from this software without specific prior written
  permission.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS ``AS
  IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
  THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR
  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
  EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
  OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
  OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
  ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
  --------------------------------------------------------------------------
  (based on BSD Open Source License)
=end

require 'watir/win32ole'

# necessary extension of win32ole 
class WIN32OLE
  def respond_to?(method)
    super || object_respond_to?(method)
  end
  
  # checks if WIN32OLE#ole_method returns an WIN32OLE_METHOD, or errors. 
  # WARNING: #ole_method is pretty slow, and consequently so is this. you are likely to be better
  # off just calling a method you are not sure exists, and rescuing the WIN32OLERuntimeError
  # that is raised if it doesn't exist. 
  def object_respond_to?(method)
    method=method.to_s
    # strip assignment = from methods. going to assume that if it has a getter method, it will take assignment, too. this may not be correct, but will have to do. 
    if method =~ /=\z/
      method=$`
    end
    respond_to_cache[method]
  end
  
  private
  def respond_to_cache
    @respond_to_cache||=Hash.new do |hash, key|
      hash[key]=begin
        !!self.ole_method(key)
      rescue WIN32OLERuntimeError
        false
      end
    end
  end
end

# create stub class since everything is defined in Watir::IE namespace - this needs to be defined before the real class.
module Watir
  class IE < Watir::Browser
  end
end

require 'logger'
require 'watir/common_elements'
require 'watir/exceptions'
require 'watir/close_all'
require 'watir/ie-process'

require 'dl/import'
require 'dl/struct'
require 'Win32API'

require 'watir/matches'

# these switches need to be deleted from ARGV to enable the Test::Unit
# functionality that grabs
# the remaining ARGV as a filter on what tests to run.
# Note: this means that watir must be require'd BEFORE test/unit.
# (Alternatively, you could require test/unit first and then put the Watir::IE
# arguments after the '--'.)

# Make Internet Explorer invisible. -b stands for background
$HIDE_IE ||= ARGV.delete('-b')

# Run fast
$FAST_SPEED = ARGV.delete('-f')

# Eat the -s command line switch (deprecated)
ARGV.delete('-s')

require 'watir/ie-class'
require 'watir/logger'
require 'watir/win32'
require 'watir/container'
require 'watir/page-container'
require 'watir/version'
require 'watir/element'
require 'watir/frame'
require 'watir/modal_dialog'
require 'watir/form'
require 'watir/non_control_elements'
require 'watir/input_elements'
require 'watir/table'
require 'watir/image'
require 'watir/link'

require 'watir'

module Watir
  include Watir::Exception

  # Directory containing the watir.rb file
  @@dir = File.expand_path(File.dirname(__FILE__))

  ATTACHER = Waiter.new
  # Like regular Ruby "until", except that a TimeOutException is raised
  # if the timeout is exceeded. Timeout is IE.attach_timeout.
  def self.until_with_timeout # block
    ATTACHER.timeout = IE.attach_timeout
    ATTACHER.wait_until { yield }
  end
end
