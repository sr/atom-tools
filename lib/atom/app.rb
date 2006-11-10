require "uri"

require "atom/http"
require "atom/element"
require "atom/collection"

module Atom
  PP_NS = "http://purl.org/atom/app#"
  
  class WrongNamespace < RuntimeError #:nodoc:
  end
  class WrongMimetype < RuntimeError # :nodoc:
  end
  class WrongResponse < RuntimeError # :nodoc:
  end

  # an Atom::Workspace has a title (Atom::Text) and an Array of Atom::Collection s
  class Workspace < Atom::Element
    element :collections, Atom::Multiple(Atom::Collection)
    element :title, Atom::Text

    def self.parse(xml, base = "")
      ws = Atom::Workspace.new("workspace")

      rxml = if xml.is_a? REXML::Document
        xml.root
      elsif xml.is_a? REXML::Element
        xml
      else 
        REXML::Document.new(xml)
      end

      xml.fill_text_construct(ws, "title")

      REXML::XPath.match( rxml, 
                          "./app:collection",
                          {"app" => Atom::PP_NS} ).each do |col_el|
        # absolutize relative URLs
        url = base + URI.parse(col_el.attributes["href"])
       
        coll = Atom::Collection.new(url, @http)

        # XXX this is a Text Construct, and should be parsed as such
        col_el.fill_text_construct(coll, "title")

        accepts = REXML::XPath.first( col_el,
                                      "./app:accept",
                                      {"app" => Atom::PP_NS} )
        coll.accepts = (accepts ? accepts.text : "entry")
        
        ws.collections << coll
      end

      ws
    end
  end


  # Atom::Service represents an Atom Publishing Protocol service document. Its only child is #workspaces, which is an Array of Atom::Workspace s
  class Service < Atom::Element
    element :workspaces, Atom::Multiple(Atom::Workspace)

    # retrieves and parses an Atom service document.
    def initialize(service_url, http = Atom::HTTP.new)
      super("service")

      @url = URI.parse(service_url)
      @http = http

      rxml = nil

      res = @http.get(@url)

      unless res.code == "200" # XXX needs to handle redirects, &c.
        raise WrongResponse, "service document URL responded with unexpected code #{res.code}"
      end

      unless res.content_type == "application/atomserv+xml"
        raise WrongMimetype, "this isn't an atom service document!"
      end

      parse(res.body)
    end
  
    private
    def parse(xml)
      rxml = if xml.is_a? REXML::Document
        xml.root
      elsif xml.is_a? REXML::Element
        xml
      else 
        REXML::Document.new(xml)
      end

      unless rxml.root.namespace == PP_NS
        raise WrongNamespace, "this isn't an atom service document!"
      end

      REXML::XPath.match( rxml, "/app:service/app:workspace", {"app" => Atom::PP_NS} ).each do |ws_el|
        self.workspaces << Atom::Workspace.parse(ws_el, @url)
      end
    end
  end
 
  class Entry
    # the @href of an entry's link[@rel="edit"]
    def edit_url
      begin
        edit_link = self.links.find do |link|
          link["rel"] == "edit"
        end

        edit_link["href"]
      rescue
        nil
      end
    end
  end
end
