require 'vapir-firefox/elements/input_element'
require 'vapir-common/elements/elements'

module Vapir
  #
  # Description:
  #   Class for Button element.
  #
  class Firefox::Button < Firefox::InputElement
    include Vapir::Button
    
    # locating should check both of these values if :caption is specified because, unlike IE,
    # ff doesn't make the value of a button be its text content when there's no value. 
    # likewise, the #caption method should pick whatever's not blank. 
    dom_attr_locate_alias :value, :caption
    dom_attr_locate_alias :textContent, :caption
    def caption
      value.empty? ? text : value
    end
  end # Button
end # Vapir
