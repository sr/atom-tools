require "atom/element"

module XHTML
  NS = "http://www.w3.org/1999/xhtml"
end

module Atom
  # An Atom::Element representing a text construct.
  # It has a single attribute, "type", which specifies how to interpret
  # the element's content. Different types are:
  #
  # text:: a plain string, without any markup (default)
  # html:: a chunk of HTML
  # xhtml:: a chunk of *well-formed* XHTML
  #
  # You should set this attribute appropriately after you set a Text
  # element (entry.content, entry.title or entry.summary).
  #
  # This content of this element can be retrieved in different formats, see #html and #xml
  class Text < Atom::Element
    attrb :type

    def initialize value # :nodoc:
      @content = value
      @content ||= "" # in case of nil
      self["type"] = "text"

      super()
    end

    # convenient, but not overly useful. see #html instead.
    def to_s
      if self["type"] == "xhtml"
        @content.children.to_s
      else
        @content.to_s
      end
    end

    # returns a string suitable for dumping into an HTML document.
    #   (or nil if that's impossible)
    #
    # if you're storing the content of a Text construct, you probably
    # want this representation.
    def html
      if self["type"] == "xhtml" or self["type"] == "html"
        to_s
      elsif self["type"] == "text"
        REXML::Text.new(to_s).to_s
      end
    end

    # attempts to parse the content of this element as XML and return it
    # as an array of REXML::Elements.
    #
    # If self["type"] is "html" and Hpricot is installed, it will
    # be converted to XHTML first.
    def xml
      xml = REXML::Element.new 'div'

      if self["type"] == "xhtml"
        @content.children.each { |child| xml << child }
      elsif self["type"] == "text"
        xml.text = self.to_s
      elsif self["type"] == "html"
        begin
          require "hpricot"
        rescue
          raise "Turning HTML content into XML requires Hpricot."
        end

        fixed = Hpricot(self.to_s, :xhtml_strict => true)
        xml = REXML::Document.new("<div>#{fixed}</div>").root
      else
        # XXX check that @type is an XML mimetype and parse it
        raise "I haven't implemented this yet"
      end

      xml
    end

    def inspect # :nodoc:
      "'#{to_s}'##{self['type']}"
    end

    def []= key, value # :nodoc:
      if key == "type"
        unless valid_type? value
          raise Atom::ParseError, "atomTextConstruct type '#{value}' is meaningless"
        end

        if value == "xhtml"
          begin
            parse_xhtml_content
          rescue REXML::ParseException
            raise Atom::ParseError, "#{@content.inspect} can't be parsed as XML"
          end
        end
      end

      super(key, value)
    end

    def to_element # :nodoc:
      e = super

      if self["type"] == "text"
        e.attributes.delete "type"
      end

      # this should be done via inheritance
      c = convert_contents e

      if c.is_a? String
        e.text = c
      elsif c.is_a? REXML::Element
        e << c.dup
      else
        raise "atom:#{local_name} can't contain type #{@content.class}"
      end

      e
    end

    private
    # converts @content based on the value of self["type"]
    def convert_contents e
      if self["type"] == "xhtml"
        @content
      elsif self["type"] == "text" or self["type"].nil? or self["type"] == "html"
        @content.to_s
      end
    end

    def valid_type? type
      ["text", "xhtml", "html"].member? type
    end

    def parse_xhtml_content xhtml = nil
      xhtml ||= @content

      @content = if xhtml.is_a? REXML::Element
        if xhtml.name == "div" and xhtml.namespace == XHTML::NS
          xhtml.dup
        else
          elem = REXML::Element.new("div")
          elem.add_namespace(XHTML::NS)

          elem << xhtml.dup

          elem
        end
      elsif xhtml.is_a? REXML::Document
        parse_xhtml_content xhtml.root
      else
        div = REXML::Document.new("<div>#{@content}</div>")
        div.root.add_namespace(XHTML::NS)

        div.root
      end
    end
  end

  # Atom::Content behaves the same as an Atom::Text, but for two things:
  #
  # * the "type" attribute can be an arbitrary media type
  # * there is a "src" attribute which is an IRI that points to the content of the entry (in which case the content element will be empty)
  class Content < Atom::Text
    attrb :src

    def html
      if self["src"]
        ""
      else
        super
      end
    end

    def to_element
      if self["src"]
        element_super = Element.instance_method(:to_element)
        return element_super.bind(self).call
      end

      super
    end

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
