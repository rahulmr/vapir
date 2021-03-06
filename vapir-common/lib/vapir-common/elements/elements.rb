require 'vapir-common/element'
require 'vapir-common/container'
require 'vapir-common/keycodes.rb'
module Vapir
  module Frame
    extend ElementHelper
    
    add_specifier :tagName => 'frame'
    add_specifier :tagName => 'iframe'
    
    container_single_method :frame
    container_collection_method :frames
    default_how :name
    
    dom_attr :name
    dom_attr :src
    inspect_these :name, :src
  end
  module InputElement
    extend ElementHelper
    
    add_specifier :tagName => 'input'
    add_specifier :tagName => 'textarea'
    add_specifier :tagName => 'button'
    add_specifier :tagName => 'select'
    
    container_single_method :input, :input_element
    container_collection_method :inputs, :input_elements
    
    dom_attr :name, :value, :type
    dom_attr :disabled => [:disabled, :disabled?]
    dom_attr :readOnly => [:readonly, :readonly?]
    dom_attr :defaultValue => :default_value
    dom_function :focus
    dom_setter :value
    inspect_these :name, :value, :type

    # Checks if this element is enabled or not. Raises ObjectDisabledException if this is disabled.
    def assert_enabled
      if disabled
        raise Exception::ObjectDisabledException, "#{self.inspect} is disabled"
      end
    end

    #   Checks if object is readonly or not. Raises ObjectReadOnlyException if this is readonly
    def assert_not_readonly
      if readonly
        raise Exception::ObjectReadOnlyException, "#{self.inspect} is readonly"
      end
    end

    # Returns true if element is enabled, otherwise returns false.
    def enabled?
      !disabled
    end
    
    module WatirInputElementConfigCompatibility
      def requires_typing
        if config.warn_deprecated
          Kernel.warn_with_caller "WARNING: #requires_typing is deprecated; please use the new config framework with config.type_keys="
        end
        config.type_keys = true
        self
      end
      def abhors_typing
        if config.warn_deprecated
          Kernel.warn_with_caller "WARNING: #abhors_typing is deprecated; please use the new config framework with config.type_keys="
        end
        config.type_keys = false
        self
      end
    end
    include WatirInputElementConfigCompatibility
  end
  module TextField
    extend ElementHelper
    parent_element_module InputElement
    
    add_specifier :tagName => 'textarea'
    add_specifier :tagName => 'input', :types => ['text', 'password', 'hidden']
    
    container_single_method :text_field
    container_collection_method :text_fields
    
    default_how :name
    
    dom_attr :size, :maxLength => :maxlength
    alias_deprecated :getContents, :value
    
    # Clears the contents of the text field.
    #
    # to be consistent with similar methods #set and #append, returns the new value, though this will always be a blank string. 
    # 
    # takes options: 
    # - :blur => true/false; whether or not to fire the onblur event when done.
    # - :highlight => true/false
    #
    # Raises UnknownObjectException if the object can't be found
    # Raises ObjectDisabledException if the object is disabled
    # Raises ObjectReadOnlyException if the object is read only
    def clear(options={})
      options={:blur => true, :change => true, :select => true, :focus => true}.merge(options)
      assert_enabled
      assert_not_readonly
      with_highlight(options) do
        if options[:focus]
          assert_exists(:force => true)
          element_object.focus
          fire_event('onFocus')
        end
        if options[:select]
          assert_exists(:force => true)
          element_object.select
          fire_event("onSelect")
        end
        handling_existence_failure do
          with_key_down(:keyCode => KeyCodes[:delete]) do
            assert_exists(:force => true)
            element_object.value = ''
          end
        end
        if options[:change] && exists?
          fire_event("onChange")
        end
        if options[:blur] && exists?
          fire_event('onBlur')
        end
        exists? ? self.value : nil
      end
    end
    private
    # todo: move to Element or something? this applies to hitting a key anywhere, really - not just TextFields. 
    def with_key_down(fire_event_options={})
      assert_exists(:force => true)
      fire_event :onKeyDown, fire_event_options
      yield if block_given?
      assert_exists(:force => true)
      fire_event :onKeyUp, fire_event_options
    end
    def type_key(key)
      # the events created by the following are sort of wrong - for firefox, only one of keyCode 
      # or charCode should ever be set. 
      # for ie, keyCode is always set and charCode is ignored (there is no such property of IE events). 
      # I could overload this method on a browser-specific basis, but having both set in ff seems to
      # do no harm, so I will not do that for the moment. 
      if PrintKeyCodes.key?(key)
        with_key_down(:keyCode => PrintKeyCodes[key]) do
          assert_exists(:force => true)
          fire_event :onKeyPress, :keyCode => key.vapir_ord, :charCode => key.vapir_ord
          yield if block_given?
        end
      elsif ShiftPrintKeyCodes.key?(key)
        with_key_down(:keyCode => KeyCodes[:shift], :shiftKey => true) do
          with_key_down(:keyCode => ShiftPrintKeyCodes[key], :shiftKey => true) do
            assert_exists(:force => true)
            fire_event :onKeyPress, :keyCode => key.vapir_ord, :charCode => key.vapir_ord, :shiftKey => true
            yield if block_given?
          end
        end
      else #?
        with_key_down do
          assert_exists(:force => true)
          fire_event :onKeyPress, :keyCode => key.vapir_ord, :charCode => key.vapir_ord
          yield if block_given?
        end
      end
    end
    public
    # Appends the specified string value to the contents of the text box.
    # 
    # returns the new value of the text field. this may not include all of what is given if there is a maxlength on the field. 
    #
    # takes options: 
    # - :blur => true/false; whether or not to file the onblur event when done.
    # - :highlight => true/false
    #
    # Raises UnknownObjectException if the object cant be found
    # Raises ObjectDisabledException if the object is disabled
    # Raises ObjectReadOnlyException if the object is read only
    def append(value, options={})
      raise ArgumentError, "Text field value must be a string! Got #{value.inspect}" unless value.is_a?(String)
      options={:blur => true, :change => true, :select => true, :focus => true}.merge(options)
      assert_enabled
      assert_not_readonly
      
      with_highlight(options) do
        existing_value_chars=element_object.value.split(//u)
        new_value_chars=existing_value_chars+value.split(//u) # IE treats the string value is set to as utf8, and this is consistent with String#ord defined in core_ext 
        if self.type.downcase=='text' && maxlength && maxlength >= 0 && new_value_chars.length > maxlength
          new_value_chars=new_value_chars[0...maxlength]
        end
        element_object.scrollIntoView
        if options[:focus]
          assert_exists(:force => true)
          element_object.focus
          fire_event('onFocus')
        end
        if options[:select]
          assert_exists(:force => true)
          element_object.select
          fire_event("onSelect")
        end
        if config.type_keys
          (existing_value_chars.length...new_value_chars.length).each do |i|
            last_key = (i == new_value_chars.length - 1)
            handling_existence_failure(:handle => (last_key ? :ignore : :raise)) do
              type_key(new_value_chars[i]) do
                assert_exists(:force => true)
                element_object.value = new_value_chars[0..i].join('')
              end
            end
            sleep config.typing_interval
          end
        else
          with_key_down do # simulate at least one keypress
            assert_exists(:force => true)
            element_object.value = new_value_chars.join('')
          end
        end
        if options[:change] && exists?
          handling_existence_failure { fire_event("onChange") }
        end
        if options[:blur] && exists?
          handling_existence_failure { fire_event('onBlur') }
        end
        wait
        exists? ? self.value : nil
      end
    end
    # Sets the contents of the text field to the given value
    #
    # returns the new value of the text field. this may be shorter than what is given if there is a maxlength on the field. 
    # 
    # takes options: 
    # - :blur => true/false; whether or not to file the onblur event when done.
    # - :highlight => true/false
    #
    # Raises UnknownObjectException if the object cant be found
    # Raises ObjectDisabledException if the object is disabled
    # Raises ObjectReadOnlyException if the object is read only
    def set(value, options={})
      with_highlight(options) do
        clear(options.merge(:blur => false, :change => false))
        append(value, options.merge(:focus => false, :select => false))
      end
    end
  end
  module Hidden
    extend ElementHelper
    parent_element_module TextField
    add_specifier :tagName => 'input', :type => 'hidden'
    container_single_method :hidden
    container_collection_method :hiddens
    default_how :name

    
    # Sets the value of this hidden field. Overriden from TextField, as there is no way to set focus and type to a hidden field
    def set(value)
      self.value=value
    end

    # Appends the value to the value of this hidden field. 
    def append(append_value)
      self.value = self.value + append_value
    end

    # Clears the value of this hidden field. 
    def clear
      self.value = ""
    end

    # Hidden element is never visible - returns false.
    def visible?
      assert_exists
      false
    end
  end
  module Button
    extend ElementHelper
    parent_element_module InputElement
    add_specifier :tagName => 'input', :types => ['button', 'submit', 'image', 'reset']
    add_specifier :tagName => 'button'
    container_single_method :button
    container_collection_method :buttons
    default_how :value

    dom_attr :src, :height, :width, :alt # these are used on <input type=image>
  end
  module FileField
    extend ElementHelper
    parent_element_module InputElement
    add_specifier :tagName => 'input', :type => 'file'
    container_single_method :file_field
    container_collection_method :file_fields
    default_how :name
  end
  module Option
    extend ElementHelper
    add_specifier :tagName => 'option'
    container_single_method :option
    container_collection_method :options
    
    inspect_these :text, :value, :selected
    dom_attr :text, :value, :selected
    
    # sets this Option's selected state to the given (true or false). 
    # will fire the onchange event on the select list if our state changes. 
    def set_selected(state, method_options={})
      method_options={:highlight => true, :wait => config.wait}.merge(method_options)
      with_highlight(method_options) do
        state_was=element_object.selected
        element_object.selected=state # TODO: if state is false and this isn't an option of a multiple select list, should this error? 
        if state_was != state
          (@extra[:select_list] || parent_select_list).fire_event(:onchange, method_options)
        end
        wait if method_options[:wait]
      end
    end
    
    def selected=(state)
      set_selected(state)
    end
    #dom_setter :selected

    # selects this option, firing the onchange event on the containing select list if we 
    # are aware of it (see #selected=) 
    def select
      self.selected=true
    end
  end
  module SelectList
    extend ElementHelper
    parent_element_module InputElement
    add_specifier :tagName => 'select'
    # in IE, type attribute is one of "select-one", "select-multiple" - but all are still the 'select' tag 
    container_single_method :select_list
    container_collection_method :select_lists
    
    dom_attr :multiple => [:multiple, :multiple?]

    # Returns an ElementCollection containing all the option elements of the select list 
    # Raises UnknownObjectException if the select box is not found
    def options
      assert_exists do
        ElementCollection.new(self, element_class_for(Vapir::Option), extra_for_contained.merge(:candidates => :options, :select_list => self))
      end
    end
    # note that the above is defined that way rather than with element_collection, as below, because adding :select_list => self to extra isn't implemented yet 
    #element_collection :options, :options, Option, proc { {:select_list => self} }

    def [](index)
      options[index]
    end

    #   Clears the selected items in the select box.
    def clear
      with_highlight do
        assert_enabled
        changed=false
        options.each do |option|
          if option.selected
            option.selected=false
            changed=true
          end
        end
        if changed
          fire_event :onchange
          wait
        end
      end
    end
    alias :clearSelection :clear
    
    # selects options whose text matches the given text. 
    # Raises NoValueFoundException if the specified value is not found.
    #
    # takes method_options hash (note, these are flags for the function, not to be confused with the Options of the select list)
    # - :wait => true/false  default true. controls whether #wait is called and whether fire_event or fire_event_no_wait is
    #   used for the onchange event. 
    def select_text(option_text, method_options={})
      select_options_if(method_options) {|option| Vapir::fuzzy_match(option.text, option_text) }
    end
    alias select select_text
    alias set select_text

    # selects options whose value matches the given value. 
    # Raises NoValueFoundException if the specified value is not found.
    #
    # takes options hash (note, these are flags for the function, not to be confused with the Options of the select list)
    # - :wait => true/false  default true. controls whether #wait is called and whether fire_event or fire_event_no_wait is
    #   used for the onchange event. 
    def select_value(option_value, method_options={})
      select_options_if(method_options) {|option| Vapir::fuzzy_match(option.value, option_value) }
    end

    # Does the SelectList have an option whose text matches the given text or regexp? 
    def option_texts_include?(text_or_regexp)
      option_texts.grep(text_or_regexp).size > 0
    end
    alias include? option_texts_include?
    alias includes? option_texts_include?

    # Is the specified option (text) selected? Raises exception of option does not exist.
    def selected_option_texts_include?(text_or_regexp)
      unless includes? text_or_regexp
        raise Vapir::Exception::UnknownObjectException, "Option #{text_or_regexp.inspect} not found."
      end
      selected_option_texts.grep(text_or_regexp).size > 0
    end
    alias selected? selected_option_texts_include?
    
    def option_texts
      options.map{|o| o.text }
    end
    alias_deprecated :getAllContents, :option_texts
    
    #   Returns an array of selected option Elements in this select list.
    #   An empty array is returned if the select box has no selected item.
    def selected_options
      options.select{|o|o.selected}
    end

    def selected_option_texts
      selected_options.map{|o| o.text }
    end
    
    alias_deprecated :getSelectedItems, :selected_option_texts

    private
    # yields each option, selects the option if the given block returns true. fires onchange event if
    # any have changed. raises Vapir::Exception::NoValueFoundException if none matched. 
    # breaks after the first match found if this is not a multiple select list. 
    # takes options hash (note, these are flags for the function, not to be confused with the Options of the select list)
    # - :wait => true/false - default is the current config.wait value. controls whether #wait is called and whether 
    #   fire_event or fire_event_no_wait is used for the onchange event. 
    def select_options_if(method_options={})
      method_options={:wait => config.wait, :highlight => true}.merge(method_options)
      raise ArgumentError, "no block given!" unless block_given?
      assert_enabled
      any_matched=false
      with_highlight(method_options) do
        handling_existence_failure do
          # using #each_by_index (rather than #each) because sometimes the OLE object goes away when a 
          # new option is selected (seems to be related to javascript events) and it has to be relocated. 
          # see documentation on ElementCollection#each_by_index vs. #each. 
          self.options.each_by_index do |option|
            # javascript events on previous option selections can cause the select list or its options to change, so this may not actually exist. but only check if we've actually done anything. 
            break if any_matched && !option.exists? 
            if yield option
              any_matched=true
              option.set_selected(true, method_options) # note that this fires the onchange event on this SelectList 
              if !self.exists? || !multiple? # javascript events firing can cause us to stop existing at this point. we should not continue if we don't exist. 
                break
              end
            end
          end
        end
        if !any_matched
          raise Vapir::Exception::NoValueFoundException, "Could not find any options matching those specified on #{self.inspect}.\nAvailable options are: \n#{options.map{|option| option.inspect}.join("\n")}"
        end
        self
      end
    end
  end
  
  module RadioCheckBoxCommon
    extend ElementClassAndModuleMethods
    dom_attr :checked => [:checked, :checked?, :set?]
    alias_deprecated :isSet?, :checked
    alias_deprecated :getState, :checked

    # Unchecks the radio button or check box element.
    # Raises ObjectDisabledException exception if element is disabled.
    def clear(options={})
      set(false, options)
    end
    
  end
  
  module Radio
    extend ElementHelper
    parent_element_module InputElement
    add_specifier :tagName => 'input', :type => 'radio'
    container_single_method :radio
    container_collection_method :radios
    add_container_method_extra_args(:value)

    include RadioCheckBoxCommon
    inspect_these :checked
    
    # Checks this radio, or clears (defaults to setting if no argument is given)
    # Raises ObjectDisabledException exception if element is disabled.
    #
    # Fires the onchange event if value changes. 
    # Fires the onclick event the state is true. 
    def set(state=true, options={})
      options=handle_options(options, :highlight => true, :wait => config.wait)
      with_highlight(options) do
        assert_enabled
        if checked!=state
          element_object.checked=state
          handling_existence_failure { fire_event(:onchange, options) } # we may stop existing due to change in state 
        end
        if state
          handling_existence_failure { fire_event(:onclick, options) } # fire this even if the state doesn't change; javascript can respond to clicking an already-checked radio. 
        end
        wait if options[:wait]
      end
      return self
    end
  end
  module CheckBox
    extend ElementHelper
    parent_element_module InputElement
    add_specifier :tagName => 'input', :type => 'checkbox'
    container_single_method :checkbox, :check_box
    container_collection_method :checkboxes, :check_boxes
    add_container_method_extra_args(:value)


    include RadioCheckBoxCommon
    inspect_these :checked
    # Checks this check box, or clears (defaults to setting if no argument is given)
    # Raises ObjectDisabledException exception if element is disabled.
    #
    # takes options:
    # * :highlight => true/false (defaults to true)
    # * :wait => true/false (defaults to true)
    def set(state=true, options={})
      options=handle_options(options, :highlight => true, :wait => config.wait)
      with_highlight(options) do
        assert_enabled
        if checked!=state
          if browser_class.name != 'Vapir::Firefox'  # compare by name to not trigger autoload or raise NameError if not loaded 
            # in firefox, firing the onclick event changes the state. in IE, it doesn't, so do that first 
            # todo/fix: this is browser-specific stuff, shouldn't it be in the browser-specific class? 
            element_object.checked=state
          end
          handling_existence_failure { fire_event(:onclick, options) } # sometimes previous actions can cause self to stop existing 
          handling_existence_failure { fire_event(:onchange, options) }
        end
        wait if options[:wait]
      end
      return self
    end
  end
  module Form
    extend ElementHelper
    add_specifier :tagName => 'form'
    container_single_method :form
    container_collection_method :forms
    default_how :name

    dom_attr :name, :action, :method => :form_method # can't use 'method' for the ruby method because it clobbers the rather important Object#method
    inspect_these :name, :action

    # Submit the form. Equivalent to pressing Enter or Return to submit a form.
    dom_function :submit
    
    private
    # these are kind of slow for large forms. 
    def set_highlight(options={})
      assert_exists do
        @elements_for_highlighting=self.input_elements.to_a
        @elements_for_highlighting.each do |element|
          element.send(:set_highlight, options)
        end
      end
    end
    def clear_highlight(options={})
      assert_exists do
        @elements_for_highlighting.each do |element|
          if element.exists?
            element.send(:clear_highlight, options)
          end
        end
      end
    end
  end
  module Image
    extend ElementHelper
    add_specifier :tagName => 'IMG'
    container_single_method :image
    container_collection_method :images
    default_how :name

    dom_attr :src, :name, :width, :height, :alt, :border
    dom_setter :border
    inspect_these :src, :name, :width, :height, :alt
    
    private
    # note: can't use alias here because set_highlight_border is defined in the Element module, which isn't included here (but it will be on the receiver) 
    def set_highlight(options={})
      set_highlight_border(options)
    end
    def clear_highlight(options={})
      clear_highlight_border(options)
    end
  end
  module HasRowsAndColumns
    # returns a TableRow which is a row of this of this Table or TBody (not in a nested table). 
    # takes the usual arguments for specifying what you want - see http://github.com/vapir/vapir/wiki/Locators
    def row(first=nil, second=nil)
      element_by_howwhat(element_class_for(Vapir::TableRow), first, second, :extra => {:candidates => :rows})
    end
    
    # returns a TableCell which is a cell of this of this Table or TBody (not in a nested table). 
    # takes the usual arguments for specifying what you want - see http://github.com/vapir/vapir/wiki/Locators
    def cell(first=nil, second=nil)
      element_by_howwhat(element_class_for(Vapir::TableCell), first, second, :extra => {:candidates => proc do |container|
        container_object=container.element_object
        object_collection_to_enumerable(container_object.rows).inject([]) do |candidates, row|
          candidates+object_collection_to_enumerable(row.cells).to_a
        end
      end})
    end
    
    # Returns a 2 dimensional array of text contents of each row and column of the table or tbody.
    def to_a
      rows.map{|row| row.cells.map{|cell| cell.text.strip}}
    end
    
    # Returns an array of hashes representing this table. This assumes that the table has one row 
    # with header information and any number of rows with data. Each element of the array is a hash 
    # whose keys are the header values (every hash has the same keys), and whose values correspond 
    # to the current row. 
    #
    #  +--------------+---------------+
    #  | First Header | Second Header |
    #  | First Data 1 | Second Data 1 |
    #  | First Data 2 | Second Data 2 |
    #  +--------------+---------------+
    #
    # Given the above table, #to_hashes will return 
    #  [{'First Header' => 'First Data 1', 'Second Header' => 'Second Data 1'}, {'First Header' => 'First Data 2', 'Second Header' => 'Second Data 2'}]
    #
    # This method will correctly account for colSpans and return text from all cells underneath a 
    # given header on one row. However, this method makes no attempt to deal with any rowSpans and 
    # will probably not work with any table with rowSpans in either the header row or data rows. 
    #
    # options:
    # - :header_count (default 1) - the number of rows before the table data start. 
    # - :header_index (default whatever :header_count is) - the index of the row that contains 
    #   header data which will be the keys of the hashes returned. (1-indexed) 
    # - :footer_count (default 0) - the number of rows to discard from the end, being footer 
    #   information and not table data. 
    # - :separator (default ' ') - used to join cells when there is more than one cell 
    #   underneath a header. 
    def to_hashes(options={})
      options=handle_options(options, {:header_count => 1, :footer_count => 0, :separator => ' '}, [:header_index])
      options[:header_index]||=options[:header_count]
      
      col_headings=rows[options[:header_index]].cells.map do |cell|
        {:colSpan => cell.colSpan || 1, :text => cell.text.strip}
      end
      
      body_range=(options[:header_count]+1 .. self.row_count-options[:footer_count])
      return body_range.map do |row_index|
        row=rows[row_index]
        # cells_by_heading will contain an array of arrays of table cells 
        # underneath the col_heading corresponding to cells_by_heading's array index. 
        # if cells do not line up underneath the column heading, exception is raised. 
        cells_by_heading=[]
        curr_heading_index=0
        cols_in_curr_heading=0
        row.cells.each do |cell|
          curr_heading=col_headings[curr_heading_index]
          cells_by_heading[curr_heading_index] ||= []
          cells_by_heading[curr_heading_index] << cell
          cols_in_curr_heading += cell.colSpan || 1
          if cols_in_curr_heading == curr_heading[:colSpan]
            curr_heading_index+=1
            cols_in_curr_heading=0
          elsif cols_in_curr_heading > curr_heading[:colSpan]
            raise "Cells underneath heading #{curr_heading[:text].inspect} do not line up!"
          end # else, we haven't got all the cells under the current heading; keep going
        end
        if curr_heading_index > col_headings.length
          raise "Too many cells for the headings!"
        elsif curr_heading_index < col_headings.length
          raise "Too few cells for the headings!"
        end
        
        col_headings.zip(cells_by_heading).inject({}) do |row_hash, (heading, cells)|
          cell_texts=cells.map(&:text).join(options[:separator]).strip
          row_hash.merge(heading[:text] => cell_texts)
        end
      end
    end

    # iterates through the rows in the table. Yields a TableRow object
    def each_row
      rows.each do |row|
        yield row
      end
    end
    alias each each_row

    # Returns the TableRow at the given index. 
    # indices start at 1.
    def [](index)
      rows[index]
    end
    
    # Returns the number of rows inside the table. does not recurse through
    # nested tables. same as (object).rows.length
    #
    # if you want the row count including nested tables (which this brokenly used to return)
    # use (object).table_rows.length 
    def row_count
      element_object.rows.length
    end
    
    def row_count_excluding_nested_tables
      raise NotImplementedError, "the method \#row_count_excluding_nested_tables is gone. the \#row_count method now returns the number of rows in this #{self.class}. for the number of rows including nested tables, use [this object].table_rows.length"
    end
    
    # returns all of the cells of this table. to get the cells including nested tables, 
    # use #table_cells, which is defined on all containers (including Table) 
    def cells
      ElementCollection.new(self, element_class_for(Vapir::TableCell), extra_for_contained.merge(:candidates => proc do |container|
        container_object=container.element_object
        object_collection_to_enumerable(container_object.rows).inject([]) do |candidates, row|
          candidates+object_collection_to_enumerable(row.cells).to_a
        end
      end))
    end
    
    # returns the number of columns of the table, either on the row at the given index
    # or (by default) on the first row.
    # takes into account any defined colSpans.
    # returns nil if the table has no rows. 
    # (if you want the number of cells - not taking into account colspans - use #cell_count
    # on the row in question)
    def column_count(index=nil)
      if index
        rows[index].column_count
      elsif row=rows.first
        row.column_count
      else
        nil
      end
    end
    #--
    # I was going to define #cell_count(index=nil) here as an alternative to #column_count
    # but it seems confusing; to me #cell_count on a Table would count up all the cells in
    # all rows, so going to avoid confusion and not do it. 
    
    # Returns an array of the text of each cell in the row at the given index.
    def row_texts_at(row_index)
      rows[row_index].cells.map do |cell|
        cell.text
      end
    end
    alias_deprecated :row_values, :row_texts_at
    
    # Returns an array containing the text of the cell in the specified index in each row. 
    def column_texts_at(column_index)
      # TODO: since this is named as 'column', not 'cell', shouldn't it return cell_at_column? 
      rows.map do |row|
        row.cells[column_index].text
      end
    end
    alias_deprecated :column_values, :column_texts_at
  end
  module TableCell
    extend ElementHelper
    add_specifier :tagName => 'td'
    add_specifier :tagName => 'th'
    container_single_method :table_cell
    container_collection_method :table_cells

    dom_attr :colSpan => [:colSpan, :colspan], :rowSpan => [:rowSpan, :rowspan]
  end
  module TableRow
    extend ElementHelper
    add_specifier :tagName => 'tr'
    container_single_method :table_row
    container_collection_method :table_rows
    
    # Returns an ElementCollection of cells in the row 
    element_collection :cells, :cells, TableCell
    
    # returns a TableCell which is a cell of this of this row (not in a nested table). 
    # takes the usual arguments for specifying what you want - see http://github.com/vapir/vapir/wiki/Locators
    def cell(first=nil, second=nil)
      element_by_howwhat(element_class_for(Vapir::TableCell), first, second, :extra => {:candidates => :cells})
    end

    # Iterate over each cell in the row. same as #cells.each. 
    def each_cell
      cells.each do |cell|
        yield cell
      end
    end
    alias each each_cell
    
    # returns the TableCell at the specified index
    def [](index)
      cells[index]
    end
    
    # the number of columns in this row, accounting for cells with a colspan attribute greater than 1 
    def column_count
      cells.inject(0) do |count, cell|
        count+ (cell.colSpan || 1)
      end
    end
    
    # the number of cells in this row 
    def cell_count
      cells.length
    end
    
    # returns the column index (starting at 0), taking into account colspans, of the table cell for which the given block returns true. 
    #
    # if nothing matches the block, returns nil. 
    def column_count_where # :yields: table_cell
      cells.inject(0) do |count, cell|
        if yield cell
          return count
        end
        count+(cell.colSpan || 1)
      end
      nil
    end
    
    # returns the cell of the current row at the given column index (starting from 0), taking
    # into account conSpans of other cells. 
    #
    # returns nil if index is greater than the number of columns of this row. 
    def cell_at_column(index)
      #TODO: test
      cells.each_by_index do |cell|
        index=index-(cell.colSpan || 1)
        return cell if index < 0
      end
      nil
    end
    
    # returns the cell of the current row at the given column index (starting from 0), taking
    # into account conSpans of other cells. 
    #
    # raises exception if the cell does not exist (that is, index is greater than the number of columns of this row). 
    def cell_at_column!(index)
      #TODO: test
      cell_at_column(index) || raise(Vapir::Exception::UnknownObjectException, "Unable to locate cell at column #{index}. Column count is #{column_count}\non container: #{@container.inspect}")
    end
  end
  module TBody
    extend ElementHelper
    add_specifier :tagName => 'TBODY'
    container_single_method :tbody
    container_collection_method :tbodies

    include HasRowsAndColumns

    # returns an ElementCollection of rows in the tbody.
    element_collection :rows, :rows, TableRow
  end
  module Table
    def self.create_from_element(container, element)
      if config.warn_deprecated
        Kernel.warn_with_caller "DEPRECATION WARNING: create_from_element is deprecated. Please use (element).parent_table (element being the second argument to this function)"
      end
      element.parent_table
    end

    extend ElementHelper
    add_specifier :tagName => 'TABLE'
    container_single_method :table
    container_collection_method :tables

    include HasRowsAndColumns
    
    # returns an ElementCollection of rows in the table.
    element_collection :rows, :rows, TableRow
    
    private
    def set_highlight(options={})
      set_highlight_color(options)
      set_highlight_border(options)
    end
    def clear_highlight(options={})
      clear_highlight_color(options)
      clear_highlight_border(options)
    end
  end
  module Link
    extend ElementHelper
    add_specifier :tagName => 'A'
    container_single_method :a, :link
    container_collection_method :as, :links

    dom_attr :name, :href => [:href, :url]
    inspect_these :href, :name
  end
  module Pre
    extend ElementHelper
    add_specifier :tagName => 'PRE'
    container_single_method :pre
    container_collection_method :pres
  end
  module P
    extend ElementHelper
    add_specifier :tagName => 'P'
    container_single_method :p
    container_collection_method :ps
  end
  module Div
    extend ElementHelper
    add_specifier :tagName => 'DIV'
    container_single_method :div
    container_collection_method :divs
  end
  module Span
    extend ElementHelper
    add_specifier :tagName => 'SPAN'
    container_single_method :span
    container_collection_method :spans
  end
  module Strong
    extend ElementHelper
    add_specifier :tagName => 'STRONG'
    container_single_method :strong
    container_collection_method :strongs
  end
  module Label
    extend ElementHelper
    add_specifier :tagName => 'LABEL'
    container_single_method :label
    container_collection_method :labels
    
    dom_attr :htmlFor => [:html_for, :for, :htmlFor]
    inspect_these :text, :for

    def for_element
      raise "document is not defined - cannot search for labeled element" unless document_object
      if for_object=document_object.getElementById(element_object.htmlFor)
        base_element_class.factory(for_object, container.extra_for_contained, :label, self)
      else
        raise Exception::UnknownObjectException, "no element found that #{self.inspect} is for!"
      end
    end
  end
  module Ul
    extend ElementHelper
    add_specifier :tagName => 'UL'
    container_single_method :ul
    container_collection_method :uls
  end
  module Ol
    extend ElementHelper
    add_specifier :tagName => 'ol'
    container_single_method :ol
    container_collection_method :ols
  end
  module Li
    extend ElementHelper
    add_specifier :tagName => 'LI'
    container_single_method :li
    container_collection_method :lis
  end
  module Dl
    extend ElementHelper
    add_specifier :tagName => 'DL'
    container_single_method :dl
    container_collection_method :dls
  end
  module Dt
    extend ElementHelper
    add_specifier :tagName => 'DT'
    container_single_method :dt
    container_collection_method :dts
  end
  module Dd
    extend ElementHelper
    add_specifier :tagName => 'DD'
    container_single_method :dd
    container_collection_method :dds
  end
  module H1
    extend ElementHelper
    add_specifier :tagName => 'H1'
    container_single_method :h1
    container_collection_method :h1s
  end
  module H2
    extend ElementHelper
    add_specifier :tagName => 'H2'
    container_single_method :h2
    container_collection_method :h2s
  end
  module H3
    extend ElementHelper
    add_specifier :tagName => 'H3'
    container_single_method :h3
    container_collection_method :h3s
  end
  module H4
    extend ElementHelper
    add_specifier :tagName => 'H4'
    container_single_method :h4
    container_collection_method :h4s
  end
  module H5
    extend ElementHelper
    add_specifier :tagName => 'H5'
    container_single_method :h5
    container_collection_method :h5s
  end
  module H6
    extend ElementHelper
    add_specifier :tagName => 'H6'
    container_single_method :h6
    container_collection_method :h6s
  end
  module Map
    extend ElementHelper
    add_specifier :tagName => 'MAP'
    container_single_method :map
    container_collection_method :maps
  end
  module Area
    extend ElementHelper
    add_specifier :tagName => 'AREA'
    container_single_method :area
    container_collection_method :areas
    
    dom_attr :alt, :href => [:url, :href]
  end
  module Em
    extend ElementHelper
    add_specifier :tagName => 'EM'
    container_single_method :em
    container_collection_method :ems
  end
end
