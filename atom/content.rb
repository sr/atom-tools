require "atom/element"

module XHTML
  NS = "http://www.w3.org/1999/xhtml"
end

module Atom 
  class Text < Atom::Element
    attrb :type
    attrb :src

    def initialize value, name
      @content = value
      @content ||= "" # in case of nil
      self["type"] = "text"
      
      super name
    end

    def to_s
      @content.to_s
    end

    def text
      to_s
    end

    def html
    end

    def xml
    end

    def inspect
      "'#{to_s}'"
    end

    def []= key, value
      if key == "type" and not valid_type? value
        raise RuntimeError, "atomTextConstruct type '#{value}' is meaningless"
      end

      super(key, value)
    end
    
    def to_element
      e = super

      if self["type"] == "text"
        e.attributes.delete "type"
      end


      unless self["src"]
        c = convert_contents e

        if c.is_a? String
          e.text = c
        elsif c.is_a? REXML::Element
          e << c
        else
          raise RuntimeError, "atom:#{local_name} can't contain type #{@content.class}"
        end
      end

      e
    end
    
    private
    def convert_contents e
      if self["type"] == "xhtml"
        xhtml = REXML::Document.new("<div>#{@content}</div>")
        xhtml.root.add_namespace(XHTML::NS)

        xhtml.root
      elsif self["type"] == "text" or self["type"].nil?
        REXML::Text.normalize(@content.to_s)
      elsif self["type"] == "html"
        # XXX is this right?
        @content.to_s
      end
    end
    
    def valid_type? type
      ["text", "xhtml", "html"].member? type
    end
  end

  class Content < Atom::Text
    attrb :type
    attrb :src

    private
    def valid_type? type
      super or type.match(/\//)
    end

    def convert_contents e
      s = super

      s ||= if @content.is_a? REXML::Document
        @content.root
      elsif @content.is_a? REXML::Element
        @content
      else
        REXML::Text.normalize(@content.to_s)
      end

      s
    end
  end
end
