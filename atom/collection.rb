require "atom/http"
require "atom/feed"

# for some *really* basic mimetype detection
require "webrick/httputils"

module Atom
  class Collection < Feed
    attr_accessor :accepts

    # this tiny little thing is here to require a URI
    def initialize(uri, http = Atom::HTTP.new)
      super
    end

    def post!(entry, slug = nil)
      headers = {"Content-Type" => "application/atom+xml" }
      headers["Slug"] = slug if slug
      
      @http.post(@uri, entry.to_s, headers)
    end
   
    def put!(entry, url = entry.edit_url)
      headers = {"Content-Type" => "application/atom+xml" }
      
      @http.put(url, entry.to_s, headers)
    end

    def delete!(entry, url = entry.edit_url)
      @http.delete(url)
    end

    def post_media!(data, content_type, slug = nil)
      headers = {"Content-Type" => content_type}
      headers["Slug"] = slug if slug
      
      @http.post(@uri, data, headers)
    end

    def put_media!(data, content_type, slug = nil)
      headers = {"Content-Type" => content_type}

      @http.put(url, data, headers)
    end
    
    # get a URL, turn it into an Atom::Entry
    #  (eg. for fetching an Entry for editing (?) )
    def get_url(url)
      res = @http.get(url)

      if res.code != "200" or res.content_type != "application/atom+xml"
        # XXX reject it
      end

      REXML::Document.new(res.body).to_atom_entry(url)
    end
  end
end
