require "time"
require "rexml/element"

module Atom # :nodoc:
  class Time < ::Time # :nodoc:
    def self.new date
      return if date.nil?

      date = if date.respond_to?(:iso8601)
        date
      else
        Time.parse date.to_s
      end
        
      def date.to_s
        iso8601
      end

      date
    end
  end
       
  # ignore the man behind the curtain.
  def self.Multiple klass
    Class.new(Array) do
      @class = klass

      def new
        item = self.class.holds.new
        self << item
      
        item
      end

      def to_element
        collect do |item| item.to_element end
      end

      def self.holds; @class end
      def self.single?; true end
      def taguri; end
    end
  end

  class Element < Hash 
    # a REXML::Element that shares this element's extension attributes
    # and child elements
    attr_reader :extensions

    # this element's xml:base
    attr_accessor :base

    # The following is a DSL for describing an atom element.

    # this element's attributes
    def self.attrs # :nodoc:
      @attrs || []
    end

    # this element's child elements
    def self.elements # :nodoc:
      @elements || []
    end

    # required child elements
    def self.required # :nodoc:
      @elements.find { |name,kind,req| req }
    end

    # copy defined elements and attributes so inheritance works
    def self.inherited klass # :nodoc:
      elements.each do |name, kind, req|
        klass.element name, kind, req
      end
      attrs.each do |name, req|
        klass.attrb name, req
      end
    end

    # define a child element
    def self.element(name, kind, req = false) # :nodoc:
      attr_reader name

      @elements ||= []
      @elements << [name, kind, req]

      unless kind.respond_to? :single?
        self.define_accessor(name,kind)
      end
    end

    # define an attribute 
    def self.attrb(name, req = false) # :nodoc:
      @attrs ||= []

      @attrs << [name, req]
    end
 
    # a little bit of magic
    def self.define_accessor(name,kind) # :nodoc:
      define_method "#{name}=".to_sym do |value|
        return unless value
        
        i = if kind.ancestors.member? Atom::Element
          kind.new(value, name.to_s)
        else
          kind.new(value)
        end
       
        set(name, i)
      end
    end

    # get the value of an attribute
    def [] key
      test_key key
   
      super
    end
    
    # set the value of an attribute
    def []= key, value
      test_key key

      super
    end

    # internal junk you probably don't care about
    def initialize name = nil # :nodoc:
      @extensions = REXML::Element.new("extensions")
      @local_name = name

      self.class.elements.each do |name,kind,req|
        if kind.respond_to? :single?
          a = kind.new
          set(name, kind.new)
        end
      end
    end

    # eg. "feed" or "entry" or "updated" or "title" or ...
    def local_name # :nodoc:
      @local_name || self.class.name.split("::").last.downcase
    end
   
    # convert to a REXML::Element (with no namespace)
    def to_element 
      elem = REXML::Element.new(local_name)

      self.class.elements.each do |name,kind,req|
        v = get(name)
        next if v.nil?

        if v.respond_to? :to_element
          e = v.to_element
          e = [ e ] unless e.is_a? Array

          e.each do |bit|
            elem << bit
          end
        else
          e = REXML::Element.new(name.to_s, elem).text = get(name)
        end
      end

      self.class.attrs.each do |name,req|
        value = self[name.to_s]
        elem.attributes[name.to_s] = value if value
      end

      self.extensions.children.each do |element|
        elem << element.dup # otherwise they get removed from @extensions
      end

      if self.base and not self.base.empty?
        elem.attributes["xml:base"] = self.base
      end

      elem
    end
    
    # convert to a REXML::Document (properly namespaced)
    def to_xml
      doc = REXML::Document.new
      root = to_element
      root.add_namespace Atom::NS
      doc << root
      doc
    end
   
    # convert to an XML string
    def to_s
      to_xml.to_s
    end
    
    def base= uri # :nodoc:
      @base = uri.to_s
    end
 
    private

    # like +valid_key?+ but raises on failure
    def test_key key
      unless valid_key? key
        raise RuntimeError, "this element (#{local_name}) doesn't have that attribute '#{key}'"
      end
    end

    # tests that an attribute 'key' has been defined
    def valid_key? key
      self.class.attrs.find { |name,req| name.to_s == key }
    end

    def get name
      instance_variable_get "@#{name}"
    end

    def set name, value
      instance_variable_set "@#{name}", value
    end
  end
  
  # this facilitates YAML output
  class AttrEl < Atom::Element # :nodoc:
  end

  # A link has the following attributes:
  #
  # href (required):: the link's IRI
  # rel:: the relationship of the linked item to the current item
  # type:: a hint about the media type of the linked item
  # hreflang:: the language of the linked item (RFC3066)
  # title:: human-readable information about the link
  # length:: a hint about the length (in octets) of the linked item
  class Link < Atom::AttrEl
    attrb :href, true
    attrb :rel
    attrb :type
    attrb :hreflang
    attrb :title
    attrb :length

    def initialize name = nil # :nodoc:
      super name

      # just setting a default
      self["rel"] = "alternate"
    end
  end
 
  # A category has the following attributes:
  #
  # term (required):: a string that identifies the category
  # scheme:: an IRI that identifies a categorization scheme
  # label:: a human-readable label
  class Category < Atom::AttrEl
    attrb :term, true
    attrb :scheme
    attrb :label
  end

  # A person construct has the following child elements:
  #
  # name (required):: a human-readable name
  # uri:: an IRI associated with the person
  # email:: an email address associated with the person
  class Author < Atom::Element
    element :name, String, true
    element :uri, String
    element :email, String
  end
 
  # same as Atom::Author
  class Contributor < Atom::Element 
    # Author and Contributor should probably inherit from Person, but
    # oh well.
    element :name, String, true
    element :uri, String
    element :email, String
  end
end
