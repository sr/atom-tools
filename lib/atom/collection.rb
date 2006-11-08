require "atom/http"
require "atom/feed"

# for some *really* basic mimetype detection
require "webrick/httputils"

module Atom
  class Collection < Feed
    attr_accessor :accepts

    # this tiny little thing is here to require a URI
    def initialize(uri, http = Atom::HTTP.new)
      super uri, http
    end

    def post!(entry, slug = nil)
      raise "Cowardly refusing to POST a non-Atom::Entry" unless entry.is_a? Atom::Entry
      headers = {"Content-Type" => "application/atom+xml" }
      headers["Slug"] = slug if slug
      
      @http.post(@uri, entry.to_s, headers)
    end
   
    def put!(entry, url = entry.edit_url)
      @http.put_atom_entry(entry, url)
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
  end

  class HTTP
    # get a URL, turn it into an Atom::Entry
    def get_atom_entry(url)
      res = get(url)

      if res.code != "200" or res.content_type != "application/atom+xml"
        raise Atom::HTTPException, "expected Atom::Entry, didn't get it"
      end

      REXML::Document.new(res.body).to_atom_entry(url)
    end

    def put_atom_entry(entry, url = entry.edit_url)
      raise "Cowardly refusing to PUT a non-Atom::Entry (#{entry.class})" unless entry.is_a? Atom::Entry
      headers = {"Content-Type" => "application/atom+xml" }
      
      put(url, entry.to_s, headers)
    end
  end
end
