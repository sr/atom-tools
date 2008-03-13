require "atom/http"
require "atom/feed"

module Atom
  # a Collection is an Atom::Feed with extra Protocol-specific methods
  class Collection < Atom::Element
    is_element PP_NS, 'collection'

    strings ['app', PP_NS], :accept, :accepts

    atom_element :title, Atom::Title
    atom_attrb :href

    def accepts
      if @accepts.empty?
        ['application/atom+xml;type=entry']
      else
        @accepts
      end
    end

    def accepts= array
      @accepts = array
    end

    attr_reader :uri
    attr_reader :http

    def local_init(uri = '', http = Atom::HTTP.new)
      @href = uri
      @http = http
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
end
