require "time"
require "rexml/element"

require 'uri'

module URI # :nodoc: all
  class Generic; def to_uri; self; end; end
end

class String # :nodoc:
  def to_uri; URI.parse(self); end
end

# cribbed from metaid.rb
class Object
   # The hidden singleton lurks behind everyone
   def metaclass; class << self; self; end; end
   def meta_eval &blk; metaclass.instance_eval &blk; end

   # Adds methods to a metaclass
   def meta_def name, &blk
     meta_eval { define_method name, &blk }
   end
end

module Atom # :nodoc:
  NS = "http://www.w3.org/2005/Atom"
  PP_NS = "http://www.w3.org/2007/app"

  class ParseError < StandardError; end

  module AttrEl
    # for backwards compatibility
    def [] k; self.send(k.to_sym); end
    def []= k, v; self.send("#{k}=".to_sym, v); end
  end

  # ignore the man behind the curtain.
  def self.Multiple klass
    Class.new(Array) do
      @class = klass

      def new *args
        item = self.class.holds.new *args
        self << item

        item
      end

      def << item
        raise ArgumentError, "this can only hold items of class #{self.class.holds}" unless item.is_a? self.class.holds

        super(item)
      end

      def self.holds; @class end
      def self.single?; true end
      def taguri; end
    end
  end

  # The Class' methods provide a DSL for describing Atom's structure
  #   (and more generally for describing simple namespaced XML)
  class Element
    # this element's xml:base
    attr_accessor :base

    # attaches a name and a namespace to an element
    # MUST be called on any new element
    def self.is_element ns, name
      meta_def :self_namespace do; ns; end
      meta_def :self_name do; name.to_s; end
    end

    def self.is_atom_element name
      self.is_element Atom::NS, name
    end

    def self.new_for_parse root
      self.new()
    end

    def get_elem xml, ns, name
      REXML::XPath.first xml, "./ns:#{name}", { 'ns' => ns }
    end

    def get_elems xml, ns, name
      REXML::XPath.match xml, "./ns:#{name}", { 'ns' => ns }
    end

    def get_atom_elem xml, name
      get_elem xml, Atom::NS, name
    end

    def get_atom_elems xml, name
      get_elems Atom::NS, name
    end

    def get_atom_attrb xml, name
      xml.attributes[name.to_s]
    end

    def set_atom_attrb xml, name, value
      # XXX namespaces
      xml.attributes[name.to_s] = value
    end

    def self.on_parse &block
      @on_parse ||= []
      @on_parse << block
    end

    def self.on_build &block
      @on_build ||= []
      @on_build << block
    end

    def self.parsers &block
      # XXX this is a bit of a hack i think
      if ancestors[1].respond_to? :parsers
        ancestors[1].parsers &block
      end

      @on_parse ||= []
      @on_parse.each &block
    end

    def self.builders &block
      # XXX this is a bit of a hack i think
      if ancestors[1].respond_to? :builders
        ancestors[1].builders &block
      end

      @on_build ||= []
      @on_build.each &block
    end

    def self.parse xml, base = ''
      root = if xml.respond_to? :elements
               xml
             else
               xml = xml.read if xml.respond_to? :read

               begin
                 REXML::Document.new(xml.to_s).root
               rescue REXML::ParseException => e
                 raise Atom::ParseError, e.message
               end
             end

      unless root.namespace == self.self_namespace
        raise Atom::ParseError, "expected element in namespace #{self.self_namespace}, not #{root.namespace}"
      end

      unless root.local_name == self.self_name
        raise Atom::ParseError, "expected element named #{self.self_name}, not #{root.local_name}"
      end

      if root.attributes['xml:base']
        base = (base.to_uri + root.attributes['xml:base'])
      end

      e = self.new_for_parse root
      e.base = base

      self.parsers do |parser|
        parser.call e, root
      end

      e
    end

    def to_xml
      root = REXML::Element.new self.class.self_name
      root.add_namespace self.class.self_namespace

      build root

      root
    end

    def build root
      if self.base and not self.base.empty?
        root.attributes['xml:base'] = self.base
      end

      self.class.builders do |builder|
        builder.call self, root
      end
    end

    def to_s
      to_xml.to_s
    end

    def self.def_get(name, &block)
      define_method name.to_sym, &block
    end

    def self.def_set(name, &block)
      define_method "#{name}=".to_sym, &block
    end

    def self.parse_plain uri, name
      self.on_parse do |e,x|
        el = e.get_elem(x, uri, name)
        el and e.set(name, el.text)
      end
    end

    def self.build_plain ns, name
      self.on_build do |e,x|
        if v = e.get(name)
          el = e.mk_elem(x, ns, name)
          el.text = v.to_s
        end
      end
    end

    def self.atom_string(name)
      attr_accessor name

      self.parse_plain(Atom::NS, name)
      self.build_plain(Atom::NS, name)
    end

    def self.time(ns, name)
      attr_reader name

      self.def_set name do |time|
        unless time.respond_to? :iso8601
          time = Time.parse(time.to_s)
        end

        def time.to_s; iso8601; end

        instance_variable_set("@#{name}", time)
      end

      define_method "#{name}!".to_sym do
        set(name, Time.now)
      end

      self.parse_plain(ns[1], name)
      self.build_plain(ns, name)
    end

    def self.atom_time(name)
      self.time ['atom', Atom::NS], name
    end

    def self.element(ns, name, klass)
      attr_reader name

      self.on_parse do |e,x|
        el = e.get_elem(x, ns[1], name)
        el and e.instance_variable_set("@#{name}", klass.parse(el, e.base))
      end

      self.on_build do |e,x|
        if v = e.get(name)
          el = e.mk_elem(x, ns, name)
          v.build(el)
        end
      end

      def_set name do |value|
        instance_variable_set("@#{name}", klass.new(value))
      end
    end

    def self.atom_element(name, klass)
      self.element(['atom', Atom::NS], name, klass)
    end

    def self.on_init &block
      @on_init ||= []
      @on_init << block
    end

    def local_init(args = {})
      if args.is_a? Hash
        args.each do |k,v|
          set(k, v)
        end
      else
        raise ArgumentError, "expected Hash or nothing for default initializer, got #{args.inspect}"
      end
    end

    def self.initters &block
      @on_init ||= []
      @on_init.each &block
    end

    def initialize *args
      self.class.initters do |init|
        self.instance_eval &init
      end

      local_init(*args)
    end

    def self.elements(ns, one_name, many_name, klass)
      attr_reader many_name

      self.on_init do
        var = Atom::Multiple(klass).new
        instance_variable_set("@#{many_name}", var)
      end

      self.on_parse do |e,x|
        var = e.get(many_name)

        e.get_elems(x, ns[1], one_name).each do |el|
          var << klass.parse(el, e.base)
        end
      end

      self.on_build do |e,x|
        if vs = e.get(many_name)
          vs.each do |v|
            el = e.mk_elem(x, ns, one_name)
            v.build(el)
          end
        end
      end
    end

   def mk_elem(root, ns, name)
      if ns.is_a? Array
        prefix, uri = ns
      else
        prefix, uri = nil, ns
      end

      name = name.to_s

      existing_prefix = root.namespaces.find do |k,v|
        v == uri
      end

      root << if existing_prefix
                prefix = existing_prefix[0]

                if prefix != 'xmlns'
                  name = prefix + ':' + name
                end

                REXML::Element.new(name)
              elsif prefix
                e = REXML::Element.new(prefix + ':' + name)
                e.add_namespace(prefix, uri)
                e
              else
                e = REXML::Element.new(name)
                e.add_namespace(uri)
                e
              end
    end

    def self.atom_elements(one_name, many_name, klass)
      self.elements(['atom', Atom::NS], one_name, many_name, klass)
    end

    def self.atom_attrb(name)
      attr_accessor name

      self.on_parse do |e,x|
        if v = e.get_atom_attrb(x, name)
          e.set name, v
        end
      end

      self.on_build do |e,x|
        if v = e.get(name)
          e.set_atom_attrb(x, name, v)
        end
      end
    end

    def self.atom_link name, criteria
      def_get name do
        existing = find_link(criteria)

        existing and existing.href
      end

      def_set name do |value|
        existing = find_link(criteria)

        if existing
          existing.href = value
        else
          links.new criteria.merge(:href => value)
        end
      end
    end

    def base= uri # :nodoc:
      @base = uri.to_s
    end

    def get name
      send "#{name}".to_sym
    end

    def set name, value
      send "#{name}=", value
    end
  end

  # A link has the following attributes:
  #
  # href (required):: the link's IRI
  # rel:: the relationship of the linked item to the current item
  # type:: a hint about the media type of the linked item
  # hreflang:: the language of the linked item (RFC3066)
  # title:: human-readable information about the link
  # length:: a hint about the length (in octets) of the linked item
  class Link < Atom::Element
    is_atom_element :link

    atom_attrb :href
    atom_attrb :rel
    atom_attrb :type
    atom_attrb :hreflang
    atom_attrb :title
    atom_attrb :length

    include AttrEl

    on_parse do |e,x|
      # URL absolutization
      if e.base and e.href
        e.href = (e.base.to_uri + e.href).to_s
      end
    end
  end

  # A category has the following attributes:
  #
  # term (required):: a string that identifies the category
  # scheme:: an IRI that identifies a categorization scheme
  # label:: a human-readable label
  class Category < Atom::Element
    is_atom_element :category

    atom_attrb :term
    atom_attrb :scheme
    atom_attrb :label

    include AttrEl
  end

  # A person construct has the following child elements:
  #
  # name (required):: a human-readable name
  # uri:: an IRI associated with the person
  # email:: an email address associated with the person
  class Person < Atom::Element
    atom_string :name
    atom_string :uri
    atom_string :email
  end

  class Author < Atom::Person
    is_atom_element :author
  end

  class Contributor < Atom::Person
    is_atom_element :contributor
  end
end
