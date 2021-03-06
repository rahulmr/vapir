require 'vapir-firefox/element'
require 'vapir-common/elements/elements'
require 'vapir-firefox/page_container'

module Vapir
  class Firefox::Frame < Firefox::Element
    include Vapir::Frame
    include Firefox::PageContainer

    def document_object
      unless @element_object
        # don't use element_object because it does assert_exists, and don't assert_exists
        # unless @element_object isn't defined at all, because element_object_exists? uses
        # the document_object, so that would infinite loop. 
        locate!
      end
      @element_object.contentDocument # OR content_window_object.document
    end
    def content_window_object
      element_object.contentWindow
    end
  end # Frame
end # Vapir
