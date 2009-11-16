require 'watir/exceptions'

module Watir
  
  def wait_until(*args)
    Waiter.wait_until(*args) {yield}
  end  

class TimeKeeper
  attr_reader :sleep_time
  def initialize 
    @sleep_time = 0.0
  end
  def sleep seconds
    @sleep_time += Kernel.sleep seconds    
  end
  def now
    Time.now
  end
end

class Waiter
  # This is an interface to a TimeKeeper which proxies
  # calls to "sleep" and "Time.now".
  # Useful for unit testing Waiter.
  attr_accessor :timer

  # How long to wait between each iteration through the wait_until
  # loop. In seconds.
  attr_accessor :polling_interval

  # Timeout for wait_until.
  attr_accessor :timeout
  
  @@default_polling_interval = 0.5
  @@default_timeout = 60.0

  def initialize(timeout=@@default_timeout,
                 polling_interval=@@default_polling_interval)
    @timeout = timeout
    @polling_interval = polling_interval
    @timer = TimeKeeper.new
  end

  # Execute the provided block until either (1) it returns true, or
  # (2) the timeout (in seconds) has been reached. If the timeout is reached,
  # a TimeOutException will be raised. The block will always
  # execute at least once.  
  # 
  # waiter = Waiter.new(5)
  # waiter.wait_until {puts 'hello'}
  # 
  # This code will print out "hello" for five seconds, and then raise a 
  # Watir::TimeOutException.
  def wait_until # block
    start_time = now
    until yield do
      if (duration = now - start_time) > @timeout
        raise Watir::Exception::TimeOutException.new(duration, @timeout),
          "Timed out after #{duration} seconds."
      end
      sleep @polling_interval
    end
  end  

  # Execute the provided block until either (1) it returns true, or
  # (2) the timeout (in seconds) has been reached. If the timeout is reached,
  # a TimeOutException will be raised. The block will always
  # execute at least once.  
  # 
  # Waiter.wait_until(5) {puts 'hello'}
  # 
  # This code will print out "hello" for five seconds, and then raise a 
  # Watir::TimeOutException.  

  # IDEA: wait_until: remove defaults from Waiter.wait_until
  def self.wait_until(timeout=@@default_timeout,
                      polling_interval=@@default_polling_interval)
    waiter = new(timeout, polling_interval)
    waiter.wait_until { yield }
  end
     
  private
  def sleep seconds
    @timer.sleep seconds
  end
  def now
    @timer.now
  end
end  
    
end # module

require 'watir/handle_options'

class WaiterError < StandardError; end
class Waiter
  # Tries for +time+ seconds to get the desired result from the given block. Stops when either:
  # 1. The :condition option (which should be a proc) returns true (that is, not false or nil)
  # 2. The block returns true (that is, anything but false or nil) if no :condition option is given
  # 3. The specified amount of time has passed. By default a WaiterError is raised. 
  #    If :exception option is given, then if it is nil, no exception is raised; otherwise it should be
  #    an exception class or an exception instance which will be raised instead of WaiterError
  #
  # Examples:
  # Waiter.try_for(30) do
  #   Time.now.year == 2015
  # end
  # Raises a WaiterError unless it is called between the last 30 seconds of December 31, 2014 and the end of 2015
  #
  # Waiter.try_for(365.242199*24*60*60, :interval => 0.1, :exception => nil, :condition => proc{ 2+2==5 }) do
  #   STDERR.puts "any decisecond now ..."
  # end
  # Complains to STDERR for one year, every tenth of a second, as long as 2+2 does not equal 5. Does not 
  # raise an exception if 2+2 does not become equal to 5. 
  def self.try_for(time, options={})
    options=handle_options(options, {:interval => 0.5, :condition => proc{|_ret| _ret}, :exception => WaiterError})
    started=Time.now
    begin
      ret=yield
      break if options[:condition].call(ret)
      sleep options[:interval]
    end while Time.now < started+time && !options[:condition].call(ret)
    if options[:exception] && !options[:condition].call(ret)
      ex=if options[:exception].is_a?(Class)
        options[:exception].new("Waiter waited #{time} seconds and condition was not met")
      else
        options[:exception]
      end
      raise ex
    end
    ret
  end
end
