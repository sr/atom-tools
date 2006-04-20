require "time"
require "rexml/element"

module Atom
  class Time < ::Time
    def self.new date
      return if date.nil? # so we can blindly copy from the XML

      date = if date.respond_to? :iso8601
        date
      else
        Time.parse date
      end
        
      def date.to_s
        iso8601
      end

      date
    end
  end
        
  def self.Multiple klass
    Class.new(Array) do
      @class = klass

      def self.holds
        @class
      end

      def new
        item = self.class.holds.new
        self << item
      
        item
      end

      def to_element
        collect do |item| item.to_element end
      end

      def self.single? 
        true 
      end
    end
  end

  class Element < Hash
    attr_reader :extensions

    def self.attrs
      @attrs || []
    end

    def self.elements
      @elements || []
    end

    def self.required
      @elements.find { |name,kind,req| req }
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
        set(name, kind.new(value))
        get(name).instance_eval do
          @local_name = name.to_s
          
          def local_name
            @local_name
          end
        end
      end
    end

    def [] key
      unless valid_key? key
        raise RuntimeError, "this element (#{local_name}) doesn't have that attribute '#{key}'"
      end

      super
    end

    def []= key, value
      unless valid_key? key
        raise RuntimeError, "this element (#{local_name}) doesn't have the attribute '#{key}'"
      end

      super
    end

    def initialize
      @extensions = REXML::Element.new("extensions")

      self.class.elements.each do |name,kind,req|
        if kind.respond_to? :single?
          a = kind.new
          set(name, kind.new)
        end
      end
    end

    def local_name
      self.class.name.split("::").last.downcase
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

      elem
    end
    
    private
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
  
  class Link < Atom::Element
    attrb :href, true
    attrb :rel
    attrb :type
    attrb :hreflang
    attrb :title
    attrb :length
  end
  
  class Category < Atom::Element
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
