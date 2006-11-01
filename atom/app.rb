require "uri"

require "atom/http"
require "atom/collection"

class WrongNamespace < RuntimeError
end

class WrongMimetype < RuntimeError
end

class WrongResponse < RuntimeError
end

module Atom
  PP_NS = "http://purl.org/atom/app#"

  class App
    attr_reader :collections

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
       
        # XXX merge collection and mediacollection
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
 
  # Entry convenience functions
  class Entry
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
