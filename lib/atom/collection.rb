require "atom/http"
require "atom/feed"

# so we can do some mimetype guessing
require "webrick/httputils"

module Atom
  # a Collection is an Atom::Feed with extra Protocol-specific methods
  class Collection < Feed
    # comma separated string that contains a list of media types
    # accepted by a collection.
    #
    # XXX I should parse this in some way, but I'm not sure what's useful 
    attr_accessor :accepts

    def initialize(uri, http = Atom::HTTP.new)
      super uri, http
    end

    # POST an entry to the collection, with an optional slug
    def post!(entry, slug = nil)
      raise "Cowardly refusing to POST a non-Atom::Entry" unless entry.is_a? Atom::Entry
      headers = {"Content-Type" => "application/atom+xml" }
      headers["Slug"] = slug if slug
      
      @http.post(@uri, entry.to_s, headers)
    end
  
    # PUT an updated version of an entry to the collection
    def put!(entry, url = entry.edit_url)
      @http.put_atom_entry(entry, url)
    end

    # DELETE an entry from the collection
    def delete!(entry, url = entry.edit_url)
      @http.delete(url)
    end

    # POST a media item to the collection
    def post_media!(data, content_type, slug = nil)
      headers = {"Content-Type" => content_type}
      headers["Slug"] = slug if slug
      
      @http.post(@uri, data, headers)
    end

    # PUT a media item to the collection
    def put_media!(data, content_type, slug = nil)
      headers = {"Content-Type" => content_type}

      @http.put(url, data, headers)
    end
  end

  class HTTP
    # GET a URL and turn it into an Atom::Entry
    def get_atom_entry(url)
      res = get(url)

      if res.code != "200" or res.content_type != "application/atom+xml"
        raise Atom::HTTPException, "expected Atom::Entry, didn't get it"
      end

      Atom::Entry.parse(res.body, url)
    end

    # PUT an Atom::Entry to a URL
    def put_atom_entry(entry, url = entry.edit_url)
      raise "Cowardly refusing to PUT a non-Atom::Entry (#{entry.class})" unless entry.is_a? Atom::Entry
      headers = {"Content-Type" => "application/atom+xml" }
      
      put(url, entry.to_s, headers)
    end
  end
end
