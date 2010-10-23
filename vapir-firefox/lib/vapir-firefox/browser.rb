=begin rdoc
   This is Vapir, Web Application Testing In Ruby using Firefox browser

   Typical usage:
    # include the controller
    require "vapir-firefox"

    # go to the page you want to test
    ff = Vapir::Firefox.start("http://myserver/mypage")

    # enter "Angrez" into an input field named "username"
    ff.text_field(:name, "username").set("Angrez")

    # enter "Ruby Co" into input field with id "company_ID"
    ff.text_field(:id, "company_ID").set("Ruby Co")

    # click on a link that has "green" somewhere in the text that is displayed
    # to the user, using a regular expression
    ff.link(:text, /green/)

    # click button that has a caption of "Cancel"
    ff.button(:value, "Cancel").click

   Vapir allows your script to read and interact with HTML objects--HTML tags
   and their attributes and contents.  Types of objects that Vapir can identify
   include:

   Type         Description
   ===========  ===============================================================
   button       <input> tags, with the type="button" attribute
   check_box    <input> tags, with the type="checkbox" attribute
   div          <div> tags
   form
   frame
   hidden       hidden <input> tags
   image        <img> tags
   label
   link         <a> (anchor) tags
   p            <p> (paragraph) tags
   radio        radio buttons; <input> tags, with the type="radio" attribute
   select_list  <select> tags, known informally as drop-down boxes
   span         <span> tags
   table        <table> tags
   text_field   <input> tags with the type="text" attribute (a single-line
                text field), the type="text_area" attribute (a multi-line
                text field), and the type="password" attribute (a
                single-line field in which the input is replaced with asterisks)

   In general, there are several ways to identify a specific object.  Vapir's
   syntax is in the form (how, what), where "how" is a means of identifying
   the object, and "what" is the specific string or regular expression
   that Vapir will seek, as shown in the examples above.  Available "how"
   options depend upon the type of object, but here are a few examples:

   How           Description
   ============  ===============================================================
   :id           Used to find an object that has an "id=" attribute. Since each
                 id should be unique, according to the XHTML specification,
                 this is recommended as the most reliable method to find an
                 object.
   :name         Used to find an object that has a "name=" attribute.  This is
                 useful for older versions of HTML, but "name" is deprecated
                 in XHTML.
   :value        Used to find a text field with a given default value, or a
                 button with a given caption
   :index        Used to find the nth object of the specified type on a page.
                 For example, button(:index, 2) finds the second button.
                 Current versions of Vapir use 1-based indexing, but future
                 versions will use 0-based indexing.
   :xpath        The xpath expression for identifying the element.

   Note that the XHTML specification requires that tags and their attributes be
   in lower case.  Vapir doesn't enforce this; Vapir will find tags and
   attributes whether they're in upper, lower, or mixed case.  This is either
   a bug or a feature.

   Vapir uses JSSh for interacting with the browser.  For further information on
   Firefox and DOM go to the following Web page:

   http://www.xulplanet.com/references/objref/

=end

require 'vapir-common/waiter'
require 'vapir-common/browser'
require 'vapir-firefox/window'
require 'vapir-firefox/modal_dialog'
require 'vapir-firefox/jssh_socket'
require 'vapir-firefox/container'
require 'vapir-firefox/page_container'

module Vapir
  include Vapir::Exception
  
  class Firefox < Browser
    include Firefox::PageContainer
    include Firefox::Window
    include Firefox::ModalDialogContainer

    def self.initialize_jssh_socket
      @@jssh_socket=JsshSocket.new
      @@firewatir_jssh_objects=@@jssh_socket.object("Vapir").assign({})
      @@jssh_socket
    end
    def self.jssh_socket(options={})
      if options[:reset] || !(class_variable_defined?('@@jssh_socket') && @@jssh_socket)
        initialize_jssh_socket
      end
      if options[:reset_if_dead]
        begin
          @@jssh_socket.assert_socket
        rescue JsshConnectionError
          Kernel.warn "WARNING: JsshSocket RESET: resetting jssh socket. Any active javascript references will not exist on the new socket!"
          initialize_jssh_socket
        end
      end
      @@jssh_socket
    end
    def self.uninitialize_jssh_socket
      @@jssh_socket=nil
      @@firewatir_jssh_objects=nil
    end
    def jssh_socket(options=nil)
      options ? self.class.jssh_socket(options) : @@jssh_socket
    end

    # Description: 
    #   Starts the firefox browser. 
    #   On windows this starts the first version listed in the registry.
    #
    # Input:
    #   options  - Hash of any of the following options:
    #     :timeout  - Time to wait for Firefox to start. By default it waits for 2 seconds.
    #                 This is done because if Firefox is not started and we try to connect
    #                 to jssh on port 9997 an exception is thrown.
    #     :profile  - The Firefox profile to use. If none is specified, Firefox will use
    #                 the last used profile.
    def initialize(options = {})
      if(options.kind_of?(Integer))
        options = {:timeout => options}
        Kernel.warn_with_caller "DEPRECATION WARNING: #{self.class.name}.new takes an options hash - passing a number is deprecated. Please use #{self.class.name}.new(:timeout => #{options[:timeout]})"
      end
      options = options_from_config(options, {:timeout => :attach_timeout, :binary_path => :firefox_binary_path, :profile => :firefox_profile}, [:attach, :goto, :wait_time])
      if options[:wait_time]
        Kernel.warn_with_caller "DEPRECATION WARNING: the :wait_time option for #{self.class.name}.new has been renamed to :timeout for consistency. Please use #{self.class.name}.new(:timeout => #{options[:wait_time]})"
        options[:timeout] = options[:wait_time]
      end
      if options[:binary_path]
        @binary_path=options[:binary_path]
      end
      
      # check for jssh not running, firefox may be open but not with -jssh
      # if its not open at all, regardless of the :suppress_launch_process option start it
      # error if running without jssh, we don't want to kill their current window (mac only)
      begin
        jssh_socket(:reset_if_dead => true).assert_socket
      rescue JsshError
        # here we're going to assume that since it's not connecting, we need to launch firefox. 
        if options[:attach]
          raise Vapir::Exception::NoBrowserException, "cannot attach using #{options[:attach].inspect} - could not connect to Firefox with JSSH"
        else
          launch_browser(options)
          # if we just launched a the browser process, attach to the window
          # that opened when we did that. 
          # but if options[:attach] is explicitly given as false (not nil), 
          # take that to mean we don't want to attach to the window launched 
          # when the process starts. 
          unless options[:attach]==false
            options[:attach]=[:title, //]
          end
        end
        ::Waiter.try_for(options[:timeout], :exception => Vapir::Exception::NoBrowserException.new("Could not connect to the JSSH socket on the browser after #{options[:timeout]} seconds. Either Firefox did not start or JSSH is not installed and listening.")) do
          begin
            jssh_socket(:reset_if_dead => true).assert_socket
            true
          rescue JsshUnableToStart
            false
          end
        end
      end
      @browser_jssh_objects = jssh_socket.object('{}').store_rand_object_key(@@firewatir_jssh_objects) # this is an object that holds stuff for this browser 
      
      if options[:attach]
        attach(*options[:attach])
      else
        open_window
      end
      set_browser_document
      set_defaults
      if options[:goto]
        goto(options[:goto])
      end
    end
    
#    def self.firefox_is_running?
      # TODO/FIX: implement!
#      true
#    end
#    def firefox_is_running?
#      self.class.firefox_is_running?
#    end

    def mozilla_window_class_name
      'MozillaUIWindowClass'
    end

    def browser
      self
    end
    
    def exists?
      # jssh_socket may be nil if the window has closed 
      jssh_socket && browser_window_object && jssh_socket.object('getWindows()').to_js_array.include(browser_window_object)
    end
    
    # Launches firebox browser
    # options as .new

    def launch_browser(options = {})
      ff_options = []
      if(options[:profile])
        ff_options += ['-no-remote', '-P', options[:profile]]
      end

      bin = path_to_bin()
      @self_launched_browser = true
      @t = Thread.new { system(bin, '-jssh', *ff_options) } # TODO: launch process in such a way that @pid can be noted 
    end
    private :launch_browser

    # Loads the given url in the browser. Waits for the page to get loaded.
    def goto(url)
      assert_exists
      browser_object.loadURI url
      wait
    end

    # Performs a HTTP POST action to an arbitrary URL with the given data. The data are represented 
    # to this method as a Hash, which is converted to the standard form of &-separated key=value 
    # strings POST data use. 
    # 
    # The data hash should be keyed with strings or symbols (which are converted to strings before 
    # being sent along), and its values should all be strings. 
    #
    # If no post_data_hash is given, the body of the POST is empty. 
    def post_to(url, post_data_hash={})
      require 'cgi'
      raise ArgumentError, "post_data_hash must be a Hash" unless post_data_hash.is_a?(Hash)
      dataString = post_data_hash.map do |(key, val)|
        unless key.is_a?(String) || key.is_a?(Symbol)
          raise ArgumentError
        end
        unless val.is_a?(String)
          raise ArgumentError
        end
        CGI.escape(key.to_s)+'='+CGI.escape(val)
      end.join("&")
      stringStream = jssh_socket.Components.classes["@mozilla.org/io/string-input-stream;1"].createInstance(jssh_socket.Components.interfaces.nsIStringInputStream)
      if jssh_socket.object('function(key, object){return (key in object);}').call('data', stringStream) # TODO: this is quite ugly; do something with it. 
        stringStream.data=dataString
      else
        stringStream.setData(dataString, dataString.unpack("U*").length)
      end
      postData = jssh_socket.Components.classes["@mozilla.org/network/mime-input-stream;1"].createInstance(jssh_socket.Components.interfaces.nsIMIMEInputStream)
      postData.addHeader("Content-Type", "application/x-www-form-urlencoded")
      postData.addContentLength = true
      postData.setData(stringStream)

      browser_object.loadURIWithFlags(url, 0, nil, nil, postData)
      wait
    end

    # Loads the previous page (if there is any) in the browser. Waits for the page to get loaded.
    def back
      if browser_object.canGoBack
        browser_object.goBack
      else
        raise Vapir::Exception::NavigationException, "Cannot go back!"
      end
      wait
    end

    # Loads the next page (if there is any) in the browser. Waits for the page to get loaded.
    def forward
      if browser_object.canGoForward
        browser_object.goForward
      else
        raise Vapir::Exception::NavigationException, "Cannot go forward!"
      end
      wait
    end

    # Reloads the current page in the browser. Waits for the page to get loaded.
    def refresh
      browser_object.reload
      wait
    end
    
    private
    # This function creates a new socket at port 9997 and sets the default values for instance and class variables.
    # Generatesi UnableToStartJSShException if cannot connect to jssh even after 3 tries.
    def set_defaults(no_of_tries = 0)
      @error_checkers = []
    end

    #   Sets the document, window and browser variables to point to correct object in JSSh.
    def set_browser_document
      unless browser_window_object
        raise "Window must be set (using open_window or attach) before the browser document can be set!"
      end
      @browser_object=@browser_jssh_objects[:browser]= ::Waiter.try_for(2, :exception => Vapir::Exception::NoMatchingWindowFoundException.new("The browser could not be found on the specified Firefox window!")) do
        if browser_window_object.respond_to?(:getBrowser)
          browser_window_object.getBrowser
        end
      end
      
      # the following are not stored elsewhere; the ref will just be to attributes of the browser, so that updating the 
      # browser (in javascript) will cause all of these refs to reflect that as well 
      @document_object=browser_object.contentDocument
      @content_window_object=browser_object.contentWindow
        # note that browser_window_object.content is the same thing, but simpler to refer to stuff on browser_object since that is updated by the nsIWebProgressListener below
      @body_object=document_object.body
      @browser_jssh_objects[:requests_in_progress]=[]
      @requests_in_progress=@browser_jssh_objects[:requests_in_progress].to_array
      @browser_jssh_objects[:unmatched_stopped_requests_count]=0
      
      @updated_at_epoch_ms=@browser_jssh_objects.attr(:updated_at_epoch_ms).assign_expr('new Date().getTime()')
      @updated_at_offset=Time.now.to_f-jssh_socket.value_json('new Date().getTime()')/1000.0
    
      # Add eventlistener for browser window so that we can reset the document back whenever there is redirect
      # or browser loads on its own after some time. Useful when you are searching for flight results etc and
      # page goes to search page after that it goes automatically to results page.
      # Details : http://zenit.senecac.on.ca/wiki/index.php/Mozilla.dev.tech.xul#What_is_an_example_of_addProgressListener.3F
      @browser_jssh_objects[:listener_object]={}
      listener_object=@browser_jssh_objects[:listener_object]
      listener_object[:QueryInterface]=jssh_socket.object(
        "function(aIID)
         { if(aIID.equals(Components.interfaces.nsIWebProgressListener) || aIID.equals(Components.interfaces.nsISupportsWeakReference) || aIID.equals(Components.interfaces.nsISupports))
           { return this;
           }
           throw Components.results.NS_NOINTERFACE;
         }")
      listener_object[:onStateChange]= jssh_socket.object(
        "function(aWebProgress, aRequest, aStateFlags, aStatus)
         { var requests_in_progress=#{@requests_in_progress.ref};
           if(aStateFlags & Components.interfaces.nsIWebProgressListener.STATE_STOP)
           { #{@updated_at_epoch_ms.ref}=new Date().getTime();
             #{browser_object.ref}=#{browser_window_object.ref}.getBrowser();
             var matched=false;
             for(var i=0; i<requests_in_progress.length; i+=1)
             { if(requests_in_progress[i].request==aRequest)
               // TODO/FIX: this doesn't seem to work reliably - possibly related to redirects? 
               // workaround is to just check if there are as many unmatched stop requests as requests 
               // in progress.
               // but this ought to be fixed to correctly match STATE_STOP requests to previously-
               // encountered STATE_START requests. 
               { requests_in_progress.splice(i, 1);
                 matched=true;
                 break;
               }
             }
             if(!matched)
             { #{@browser_jssh_objects.attr(:unmatched_stopped_requests_count).ref}++; //.push({webProgress: aWebProgress, request: aRequest, stateFlags: aStateFlags, status: aStatus});
               // count any stop requests that we fail to match so that we can compare that count to the number of unmatched start requests. 
             }
           }
           if(aStateFlags & Components.interfaces.nsIWebProgressListener.STATE_START)
           { requests_in_progress.push({webProgress: aWebProgress, request: aRequest, stateFlags: aStateFlags, status: aStatus});
           }
           // the below was kind of a hack to get rid of any requests which 
           // are done but were not matched to a STATE_STOP request. 
           // it doesn't seem to work very well, so commented.
           /*
           for(var i=0; i<requests_in_progress.length; ++i)
           { var request_in_progress=requests_in_progress[i];
             if(request_in_progress.request.loadGroup.activeCount==0)
             { requests_in_progress.splice(i, 1);
               --i;
             }
           }*/
         }")
      browser_object.addProgressListener(listener_object)
    end

    public
    attr_reader :browser_window_object
    attr_reader :content_window_object
    attr_reader :browser_object
    attr_reader :document_object
    attr_reader :body_object
    
    def updated_at
      Time.at(@updated_at_epoch_ms.val/1000.0)+@updated_at_offset
    end

    public
    # Closes the browser window.
    #
    # This will also quit the browser (see #quit_browser) only if this instance of Vapir::Firefox launched the browser when 
    # it was created, AND there are no other windows remaining open. On Windows, closing the last browser window quits
    # the browser anyway; on other operating systems it does not. 
    def close
      assert_exists
      begin
        browser_window_object.close
        # TODO/fix timeout; this shouldn't be a hard-coded magic number. 
        ::Waiter.try_for(32, :exception => Exception::WindowFailedToCloseException.new("The browser window did not close")) do
          !exists?
        end
        jssh_socket.assert_socket
      rescue JsshConnectionError # the socket may disconnect when we close the browser, causing the JsshSocket to complain 
        Vapir::Firefox.uninitialize_jssh_socket
      end
      @browser_window_object=@browser_object=@document_object=@content_window_object=@body_object=nil
      if @self_launched_browser && jssh_socket && !self.class.window_objects.any?{ true }
        quit_browser(:force => false)
      end
    end

    # Closes all firefox windows by quitting the browser 
    def close_all
      quit_browser(:force => false)
    end

    module FirefoxClassAndInstanceMethods
      # quits the browser. 
      #
      # quit_browser(:force => true) will force the browser to quit. 
      #
      # if there is no existing connection to JSSH, this will attempt to create one. If that fails, JsshUnableToStart will be raised. 
      def quit_browser(options={})
        jssh_socket(:reset_if_dead => true).assert_socket
        options=handle_options(options, :force => false)
        # from https://developer.mozilla.org/en/How_to_Quit_a_XUL_Application
        appStartup= jssh_socket.Components.classes['@mozilla.org/toolkit/app-startup;1'].getService(jssh_socket.Components.interfaces.nsIAppStartup)
        quitSeverity = options[:force] ? jssh_socket.Components.interfaces.nsIAppStartup.eForceQuit : jssh_socket.Components.interfaces.nsIAppStartup.eAttemptQuit
        begin
          appStartup.quit(quitSeverity)
          ::Waiter.try_for(8, :exception => Exception::WindowFailedToCloseException.new("The browser did not quit")) do
            jssh_socket.assert_socket # this should error, going up past the waiter to the rescue block above 
            false
          end
        rescue JsshConnectionError
          Vapir::Firefox.uninitialize_jssh_socket
        end
        # TODO/FIX: poll to wait for the process itself to finish? the socket closes (which we wait for 
        # above) before the process itself has exited, so if Firefox.new is called between the socket 
        # closing and the process exiting, Firefox pops up with:
        #  Close Firefox
        #  A copy of Firefox is already open. Only one copy of Firefox can be open at a time.
        #  [OK]
        # until that's implemented, just wait for an arbitrary amount of time. (ick)
        sleep 2
      
        @browser_window_object=@browser_object=@document_object=@content_window_object=@body_object=nil
        nil
      end
      
      # returns the pid of the currently-attached Firefox process. 
      #
      # This only works on Firefox >= 3.6, on platforms supported (see #current_os), and raises 
      # NotImplementedError if it can't get the pid. 
      def pid
        @pid ||= begin
          begin
            ctypes = jssh_socket.Components.utils.import("resource://gre/modules/ctypes.jsm").ctypes
          rescue JsshJavascriptError
            raise NotImplementedError, "Firefox 3.6 or greater is required for this method.\n\nOriginal error from firefox: #{$!.class}: #{$!.message}", $!.backtrace
          end
          lib, pidfunction, abi = *case current_os
          when :macosx
            ["libc.dylib", 'getpid', ctypes.default_abi]
          when :linux
            ["libc.so.6", 'getpid', ctypes.default_abi]
          when :windows
            ['kernel32', 'GetCurrentProcessId', ctypes.stdcall_abi]
          else
            raise NotImplementedError, "don't know how to get pid for #{current_os}"
          end
          getpid = ctypes.open(lib).declare(pidfunction, abi, ctypes.int32_t)
          getpid.call()
        end
      end

      # returns a symbol representing the platform we're currently running on - currently 
      # implemented platforms are :windows, :macosx, and :linux. raises NotImplementedError if the 
      # current platform isn't one of those. 
      def current_os
        @current_os ||= begin
          platform= if RUBY_PLATFORM =~ /java/
            require 'java'
            java.lang.System.getProperty("os.name")
          else
            RUBY_PLATFORM
          end
          case platform
          when /mswin|windows|mingw32/i
            :windows
          when /darwin|mac os/i
            :macosx
          when /linux/i
            :linux
          else
            raise NotImplementedError, "Unidentified platform #{platform}"
          end
        end
      end
    end
    include FirefoxClassAndInstanceMethods
    extend FirefoxClassAndInstanceMethods

    

    #   Used for attaching pop up window to an existing Firefox window, either by url or title.
    #   ff.attach(:url, 'http://www.google.com')
    #   ff.attach(:title, 'Google')
    #
    # Output:
    #   Instance of newly attached window.
    def attach(how, what)
      @browser_window_object = case how
      when :browser_window_object
        what
      else
        find_window(how, what)
      end
      
      unless @browser_window_object
        raise Exception::NoMatchingWindowFoundException.new("Unable to locate window, using #{how} and #{what}")
      end
      set_browser_document
      self
    end
    private :attach

    # loads up a new window in an existing process
    # Vapir::Browser.attach() with no arguments passed the attach method will create a new window
    # this will only be called one time per instance we're only ever going to run in 1 window
    def open_window
      begin
        @browser_window_name="firewatir_window_%.16x"%rand(2**64)
      end while self.class.browser_window_objects.any?{|browser_window_object| browser_window_object.name == @browser_window_name }
      watcher=jssh_socket.Components.classes["@mozilla.org/embedcomp/window-watcher;1"].getService(jssh_socket.Components.interfaces.nsIWindowWatcher)
      # nsIWindowWatcher is used to launch new top-level windows. see https://developer.mozilla.org/en/Working_with_windows_in_chrome_code
      
      @browser_window_object=@browser_jssh_objects[:browser_window]=watcher.openWindow(nil, 'chrome://browser/content/browser.xul', @browser_window_name, 'resizable', nil)
      return @browser_window_object
    end
    private :open_window

    def self.each
      each_browser_window_object do |win|
        yield self.attach(:browser_window_object, win)
      end
    end

    def self.each_browser_window_object
      mediator=jssh_socket.Components.classes["@mozilla.org/appshell/window-mediator;1"].getService(jssh_socket.Components.interfaces.nsIWindowMediator)
      enumerator=mediator.getEnumerator("navigator:browser")
      while enumerator.hasMoreElements
        win=enumerator.getNext
        yield win
      end
      nil
    end
    def self.browser_window_objects
      Enumerator.new(self, :each_browser_window_object)
    end
    def self.each_window_object
      mediator=jssh_socket.Components.classes["@mozilla.org/appshell/window-mediator;1"].getService(jssh_socket.Components.interfaces.nsIWindowMediator)
      enumerator=mediator.getEnumerator(nil)
      while enumerator.hasMoreElements
        win=enumerator.getNext
        yield win
      end
      nil
    end
    def self.window_objects
      Enumerator.new(self, :each_window_object)
    end
    
    # return the window jssh object for the browser window with the given title or url.
    #   how - :url or :title
    #   what - string or regexp
    #
    # Start searching windows in reverse order so that we attach/find the latest opened window.
    def find_window(how, what)
      orig_how=how
      hows={ :title => proc{|content_window| content_window.title },
             :URL => proc{|content_window| content_window.location.href },
           }
      how=hows.keys.detect{|h| h.to_s.downcase==orig_how.to_s.downcase}
      raise ArgumentError, "how should be one of: #{hows.keys.inspect} (was #{orig_how.inspect})" unless how
      found_win=nil
      self.class.each_browser_window_object do |win|
        found_win=win if Vapir::fuzzy_match(hows[how].call(win.getBrowser.contentDocument),what)
        # we don't break here if found_win is set because we want the last match if there are multiple. 
      end
      return found_win
    end
    private :find_window

    #   Returns the Status of the page currently loaded in the browser from statusbar.
    #
    # Output:
    #   Status of the page.
    #
    def status
      #content_window_object.status
      browser_window_object.XULBrowserWindow.statusText
    end

    # Returns the text of the page currently loaded in the browser.
    def text
      body_object.textContent
    end

    # the HTTP response status code for the currently loaded document 
    def response_status_code
      channel = nil
      ::Waiter.try_for(8, :exception => nil) do
        channel=browser.browser_object.docShell.currentDocumentChannel
        channel.is_a?(JsshObject) && channel.instanceof(browser.jssh_socket.Components.interfaces.nsIHttpChannel) && channel.respond_to?(:responseStatus)
      end || raise(RuntimeError, "expected currentDocumentChannel to exist and be a nsIHttpChannel but it wasn't; was #{channel.is_a?(JsshObject) ? channel.toString : channel.inspect}")
      status = channel.responseStatus
    end
    
    # Maximize the current browser window.
    def maximize()
      browser_window_object.maximize
    end

    # Minimize the current browser window.
    def minimize()
      browser_window_object.minimize
    end

    # Waits for the page to get loaded.
    def wait(options={})
      return unless exists?
      unless options.is_a?(Hash)
        raise ArgumentError, "given options should be a Hash, not #{options.inspect} (#{options.class})\nold conflicting arguments of no_sleep or last_url are gone"
      end
      options={:sleep => false, :last_url => nil, :timeout => 120}.merge(options)
      started=Time.now
      ::Waiter.try_for(options[:timeout] - (Time.now - started), :exception => "Waiting for the document to finish loading timed out") do
        browser_object.webProgress.isLoadingDocument==false
      end

      # If the redirect is to a download attachment that does not reload this page, this
      # method will loop forever. Therefore, we need to ensure that if this method is called
      # twice with the same URL, we simply accept that we're done.
      url= document_object.URL

      if(url != options[:last_url])
        # Check for Javascript redirect. As we are connected to Firefox via JSSh. JSSh
        # doesn't detect any javascript redirects so check it here.
        # If page redirects to itself that this code will enter in infinite loop.
        # So we currently don't wait for such a page.
        # wait variable in JSSh tells if we should wait more for the page to get loaded
        # or continue. -1 means page is not redirected. Anyother positive values means wait.
        metas=document_object.getElementsByTagName 'meta'
        wait_time=metas.to_array.map do |meta|
          return_time=true
          return_time &&= meta.httpEquiv =~ /\Arefresh\z/i 
          return_time &&= begin
            content_split=meta.content.split(';')
            content_split[1] && content_split[1] !~ /\A\s*url=#{Regexp.escape(url)}\s*\z/ # if there is no url, or if the url is the current url, it's just a reload, not a redirect; don't wait. 
          end
          return_time ? content_split[0].to_i : nil
        end.compact.max
        
        if wait_time
          if wait_time > (options[:timeout] - (Time.now - started)) # don't wait longer than what's left in the timeout would for any other timeout. 
            raise "waiting for a meta refresh would take #{wait_time} seconds but remaining time before timeout is #{options[:timeout] - (Time.now - started)} seconds - giving up"
          end
          sleep(wait_time)
          wait(:last_url => url, :timeout => options[:timeout] - (Time.now - started))
        end
      end
      ::Waiter.try_for(options[:timeout] - (Time.now - started), :exception => "Waiting for requests in progress to complete timed out.") do
        @requests_in_progress.length<=@browser_jssh_objects[:unmatched_stopped_requests_count]
      end
      run_error_checks
      return self
    end

    # saves a screenshot of this browser window to the given filename. 
    #
    # the last argument is an optional options hash, taking options:
    # - :dc => context to capture (stands for device context). default is :page. may be one of: 
    #   - :page takes a screenshot of the full page, and none of the browser chrome. this is supported cross-platform. 
    #   - :client takes a screenshot of the client area, which excludes the menu bar and other window trimmings. 
    #     only supported on windows. 
    #   - :window takes a screenshot of the full browser window. only supported on windows. 
    #   - :desktop takes a screenshot of the full desktop. only supported on windows. 
    # - :format => a valid format. if :dc is :window, the default is 'png' ('jpeg' is also supported); if :dc is anything else, 'bmp' is both the
    #   default and the only supported format. 
    def screen_capture(filename, options = {})
      options = handle_options(options, :format => nil, :dc => :page)
      
      if options[:dc] == :page
        options[:format] ||= 'png'
        jssh_socket.call_function(:window => content_window_object, :options => options, :filename => File.expand_path(filename)) do
        %q(
          // this is adapted from Selenium's method Selenium.prototype.doCaptureEntirePageScreenshot
          var document = window.document;
          var document_element = document.documentElement;
          var width = document_element.scrollWidth;
          var height = document_element.scrollHeight;
          var styleWidth = width.toString() + 'px';
          var styleHeight = height.toString() + 'px';

          var canvas = document.createElementNS('http://www.w3.org/1999/xhtml', 'html:canvas'), grabCanvas=canvas;
          grabCanvas.style.display = 'none';
          grabCanvas.width = width;
          grabCanvas.style.width = styleWidth;
          grabCanvas.style.maxWidth = styleWidth;
          grabCanvas.height = height;
          grabCanvas.style.height = styleHeight;
          grabCanvas.style.maxHeight = styleHeight;
          
          document_element.appendChild(canvas);
          try
          {
            var context = canvas.getContext('2d');
            context.clearRect(0, 0, width, height);
            context.save();
            
            var prefs=Components.classes['@mozilla.org/preferences-service;1'].getService(Components.interfaces.nsIPrefBranch);
            var background_color = prefs.getCharPref('browser.display.background_color');
            
            context.drawWindow(window, 0, 0, width, height, background_color);
            context.restore();
            var dataUrl = canvas.toDataURL("image/" + options['format']);
            
            var nsIoService = Components.classes["@mozilla.org/network/io-service;1"].getService(Components.interfaces.nsIIOService);
            var channel = nsIoService.newChannelFromURI(nsIoService.newURI(dataUrl, null, null));
            var binaryInputStream = Components.classes["@mozilla.org/binaryinputstream;1"].createInstance(Components.interfaces.nsIBinaryInputStream);
            binaryInputStream.setInputStream(channel.open());
            var numBytes = binaryInputStream.available();
            var bytes = binaryInputStream.readBytes(numBytes);

            var nsFile = Components.classes["@mozilla.org/file/local;1"].createInstance(Components.interfaces.nsILocalFile);
            nsFile.initWithPath(filename);
            var writeFlag = 0x02; // write only
            var createFlag = 0x08; // create
            var truncateFlag = 0x20; // truncate
            var fileOutputStream = Components.classes["@mozilla.org/network/file-output-stream;1"].createInstance(Components.interfaces.nsIFileOutputStream);
            fileOutputStream.init(nsFile, writeFlag | createFlag | truncateFlag, 0664, null);
            fileOutputStream.write(bytes, numBytes);
            fileOutputStream.close();
            document_element.removeChild(canvas);
          }
          catch(e)
          { document_element.removeChild(canvas);
          }
        )
        end
      else
        screen_capture_win_window(filename, options)
      end
    end

    # Add an error checker that gets called on every page load.
    # * checker - a Proc object
    def add_checker(checker)
      @error_checkers << checker
    end

    # Disable an error checker
    # * checker - a Proc object that is to be disabled
    def disable_checker(checker)
      @error_checkers.delete(checker)
    end

    # Run the predefined error checks. This is automatically called on every page load.
    def run_error_checks
      @error_checkers.each { |e| e.call(self) }
    end


    def startClicker(*args)
      raise NotImplementedError, "startClicker is gone. Use Firefox#modal_dialog.click_button (generally preceded by a Element#click_no_wait)"
    end

    private

    def path_to_bin
      path = @binary_path || begin
        case current_os
        when :windows
          path_from_registry
        when :macosx
          path_from_spotlight
        when :linux
          `which firefox`.strip
        end
      end
      raise "unable to locate Firefox executable" if path.nil? || path.empty?
      path
    end

    def path_from_registry
      raise NotImplementedError, "(need to know how to access windows registry on JRuby)" if RUBY_PLATFORM =~ /java/
      require 'win32/registry'
      lm = ::Win32::Registry::HKEY_LOCAL_MACHINE
      lm.open('SOFTWARE\Mozilla\Mozilla Firefox') do |reg|
        reg1 = lm.open("SOFTWARE\\Mozilla\\Mozilla Firefox\\#{reg.keys[0]}\\Main")
        if entry = reg1.find { |key, type, data| key =~ /pathtoexe/i }
          return entry.last
        end
      end
    end

    def path_from_spotlight
      ff = %x[mdfind 'kMDItemCFBundleIdentifier == "org.mozilla.firefox"']
      ff = ff.empty? ? '/Applications/Firefox.app' : ff.split("\n").first

      "#{ff}/Contents/MacOS/firefox-bin"
    end

    private
    def base_element_class
      Firefox::Element
    end
    def browser_class
      Firefox
    end
  end # Firefox
end # Vapir
