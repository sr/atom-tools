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
      
      @collections = {}
      
      colls.each do |collection|
        title = collection.attributes["title"]

        # to account for relative URLs
        url = i_url + URI.parse(collection.attributes["href"])
        @collections[title] = Atom::Collection.new(url, http)
      end
    end
  end
 
  # Entry convenience functions
  class Entry
    def edit_url
      edit_link = self.links.find do |link|
        link["rel"] == "edit"
      end

      unless edit_link["href"]
        raise RuntimeError, "you don't know where this entry has been!"
      end

      edit_link["href"]
    end
  end
end
