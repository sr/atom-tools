require "atom/http"
require "atom/feed"

# for some *really* basic mimetype detection
require "webrick/httputils"

module Atom
  class Collection < Feed
    # a collection with no uri doesn't make sense
    def initialize(uri, http = Atom::HTTP.new)
      super
    end

    def post!(entry)
      headers = {"Content-Type" => "application/atom+xml" }
      
      @http.post(@uri, entry.to_s, headers)
    end

    def delete!(entry, url = entry.edit_url)
      @http.delete(url)
    end

    def put!(entry, url = entry.edit_url)
      headers = {"Content-Type" => "application/atom+xml" }
      
      @http.put(url, entry.to_s, headers)
    end
   
    # get a URL, turn it into an Atom::Entry
    def get_url(url)
      res = @http.get(url)

      if res.code != "200" or res.content_type != "application/atom+xml"
        # reject it
      end

      REXML::Document.new(res.body).to_atom_entry(url)
    end
  end

  class MediaCollection < Collection
    def post!(title, data, content_type)
      headers = {"Content-Type" => content_type, "Title" => title}
      
      @http.post(@uri, data, headers)
    end

    def put!(title, entry, data, content_type, url = entry.edit_url)
      headers = {"Content-Type" => content_type, "Title" => title}

      @http.put(url, data, headers)
    end
  end
end
