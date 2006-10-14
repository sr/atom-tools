require "time"
require "rexml/element"

module Atom
  class Time < ::Time
    def self.new date
      return if date.nil? # so we can blindly copy from the XML

      date = if date.respond_to?(:iso8601); date else Time.parse date; end
        
      def date.to_s
        iso8601
      end

      date
    end
  end
        
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
      def taguri; nil end
    end
  end

  class Element < Hash
    attr_reader :extensions
    attr_accessor :base

    def self.attrs; @attrs || [] end
    def self.elements; @elements || [] end

    def self.required
      @elements.find { |name,kind,req| req }
    end

    def self.inherited klass
      elements.each do |name, kind, req|
        klass.element name, kind, req
      end
      attrs.each do |name, req|
        klass.attrb name, req
      end
    end

    def self.element(name, kind, req = false)
      attr_reader name

      @elements ||= []
      @elements << [name, kind, req]

      unless kind.respond_to? :single?
        self.define_accessor(name,kind)
      end
    end

    def self.attrb(name, req = false)
      @attrs ||= []

      @attrs << [name, req]
    end
    
    def self.define_accessor(name,kind)
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

    def [] key
      test_key key
   
      super
    end
     
    def []= key, value
      test_key key

      super
    end

    def initialize name = nil
      @extensions = REXML::Element.new("extensions")
      @local_name = name

      self.class.elements.each do |name,kind,req|
        if kind.respond_to? :single?
          a = kind.new
          set(name, kind.new)
        end
      end
    end

    def local_name
      @local_name || self.class.name.split("::").last.downcase
    end
    
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
    
    # guess.
    def to_xml
      doc = REXML::Document.new
      root = to_element
      root.add_namespace Atom::NS
      doc << root
      doc
    end
    
    # you're not even trying now.
    def to_s
      to_xml.to_s
    end
    
    private
    def test_key key
      unless valid_key? key
        raise RuntimeError, "this element (#{local_name}) doesn't have that attribute '#{key}'"
      end
    end

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
  class AttrEl < Atom::Element; end

  class Link < Atom::AttrEl
    attrb :href, true
    attrb :rel
    attrb :type
    attrb :hreflang
    attrb :title
    attrb :length

    def initialize name = nil
      super name

      # just setting a default
      self["rel"] = "alternate"
    end
  end
  
  class Category < Atom::AttrEl
    attrb :term, true
    attrb :scheme
    attrb :label
  end

  class Author < Atom::Element
    element :name, String, true
    element :uri, String
    element :email, String
  end
  
  class Contributor < Atom::Element
    element :name, String, true
    element :uri, String
    element :email, String
  end
end
