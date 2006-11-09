require "uri"

require "atom/http"
require "atom/collection"

module Atom
  PP_NS = "http://purl.org/atom/app#"
  
  class WrongNamespace < RuntimeError #:nodoc:
  end
  class WrongMimetype < RuntimeError # :nodoc:
  end
  class WrongResponse < RuntimeError # :nodoc:
  end

  # Atom::App represents an Atom Publishing Protocol introspection
  # document.
  class App
    # collections referred to by the introspection document
    attr_reader :collections

    # retrieves and parses an Atom introspection document.
    def initialize(introspection_url, http = Atom::HTTP.new)
      i_url = URI.parse(introspection_url)

      rxml = nil

      res = http.get(i_url)

      unless res.code == "200" # redirects, &c.
        raise WrongResponse, "introspection document responded with unexpected code #{res.code}"
      end

      unless res.content_type == "application/atomserv+xml"
        raise WrongMimetype, "this isn't an introspection document!"
      end

      rxml = REXML::Document.new(res.body)

      unless rxml.root.namespace == PP_NS
        raise WrongNamespace, "this isn't an introspection document!"
      end

      # TODO: expose workspaces
      colls = REXML::XPath.match( rxml, 
                                  "/app:service/app:workspace/app:collection",
                                  {"app" => Atom::PP_NS} )
      
      @collections = []
      
      colls.each do |collection|
        # absolutize relative URLs
        url = i_url + URI.parse(collection.attributes["href"])
       
        coll = Atom::Collection.new(url, http)

        # XXX I think this is a Text Construct now
        coll.title = REXML::XPath.first( collection,
                                    "./atom:title",
                                    {"app" => Atom::PP_NS,
                                     "atom" => Atom::NS   } ).text

        accepts = REXML::XPath.first( collection,
                                      "./app:accept",
                                      {"app" => Atom::PP_NS} )
        coll.accepts = (accepts ? accepts.text : "entry")
        
        @collections << coll
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
