require "uri"

require "atom/http"
require "atom/element"
require "atom/collection"

module Atom
  # an Atom::Workspace has a #title (Atom::Text) and #collections, an Array of Atom::Collection s
  class Workspace < Atom::Element
    element :collections, Atom::Multiple(Atom::Collection)
    element :title, Atom::Text

    def self.parse(xml, base = "", http = Atom::HTTP.new) # :nodoc:
      ws = Atom::Workspace.new("workspace")

      rxml = if xml.is_a? REXML::Document
        xml.root
      elsif xml.is_a? REXML::Element
        xml
      else
        begin
          REXML::Document.new(xml)
        rescue REXML::ParseException
          raise Atom::ParseError
        end
      end

      xml.fill_text_construct(ws, "title")

      REXML::XPath.match( rxml,
                          "./app:collection",
                          {"app" => Atom::PP_NS} ).each do |col_el|
        # absolutize relative URLs
        url = base.to_uri + col_el.attributes["href"].to_uri

        coll = Atom::Collection.new(url, http)

        col_el.fill_text_construct(coll, "title")

        accepts = REXML::XPath.first( col_el,
                                      "./app:accept",
                                      {"app" => Atom::PP_NS} )

        accepts = []
        REXML::XPath.each(col_el, "./app:accept", {"app" => Atom::PP_NS}) do |a|
          accepts << a.texts.join
        end

        coll.accepts = (accepts.empty? ? ["application/atom+xml;type=entry"] : accepts)

        ws.collections << coll
      end

      ws
    end

    def to_element # :nodoc:
      root = REXML::Element.new "workspace"

      if self.title
        title = self.title.to_element
        title.name = "atom:title"
        root << title
      end

      self.collections.each do |coll|
        el = REXML::Element.new "collection"

        el.attributes["href"] = coll.uri.to_s

        title = coll.title.to_element
        title.name = "atom:title"
        el << title

        unless coll.accepts.nil?
          coll.accepts.each do |acc|
            accept = REXML::Element.new "accept"
            accept.text = acc
            el << accept
          end
        end

        root << el
      end

      root
    end
  end

  # Atom::Service represents an Atom Publishing Protocol service
  # document. Its only child is #workspaces, which is an Array of
  # Atom::Workspace s
  class Service < Atom::Element
    element :workspaces, Atom::Multiple(Atom::Workspace)

    # retrieves and parses an Atom service document.
    def initialize(service_url = "", http = Atom::HTTP.new)
      super("service")

      @http = http

      return if service_url.empty?

      base = URI.parse(service_url)

      rxml = nil

      res = @http.get(base, "Accept" => "application/atomsvc+xml")
      res.validate_content_type(["application/atomsvc+xml"])

      unless res.code == "200"
        raise Atom::HTTPException, "Unexpected HTTP response code: #{res.code}"
      end

      parse(res.body, base)
    end

    def self.parse xml, base = ""
      Atom::Service.new.parse(xml, base)
    end

    def collections
      self.workspaces.map { |ws| ws.collections }.flatten
    end

    # parse a service document, adding its workspaces to this object
    def parse xml, base = ""
      rxml = if xml.is_a? REXML::Document
        xml.root
      elsif xml.is_a? REXML::Element
        xml
      else
        REXML::Document.new(xml)
      end

      unless rxml.root.namespace == PP_NS
        raise Atom::ParseError, "this isn't an atom service document! (wrong namespace: #{rxml.root.namespace})"
      end

      REXML::XPath.match( rxml, "/app:service/app:workspace", {"app" => Atom::PP_NS} ).each do |ws_el|
        self.workspaces << Atom::Workspace.parse(ws_el, base, @http)
      end

      self
    end

    # serialize to a (namespaced) REXML::Document
    def to_xml
      doc = REXML::Document.new

      root = REXML::Element.new "service"
      root.add_namespace Atom::PP_NS
      root.add_namespace "atom", Atom::NS

      self.workspaces.each do |ws|
        root << ws.to_element
      end

      doc << root
      doc
    end
  end
end
