require "atom/element"
require "atom/content"
require "atom/entry"

require "atom/http"

module Atom
  class Feed < Atom::Element
    attr_reader :uri, :prev, :next, :etag, :last_modified

    element :id, String, true
    element :title, Atom::Text, true
    element :subtitle, Atom::Text
   
    element :updated, Atom::Time, true

    element :links, Atom::Multiple(Atom::Link)
    element :categories, Atom::Multiple(Atom::Category)

    element :authors, Atom::Multiple(Atom::Author)
    element :contributors, Atom::Multiple(Atom::Contributor)

    element :generator, String # XXX with uri and version attributes!
    element :icon, String
    element :logo, String

    element :rights, Atom::Text
    
    element :entries, Atom::Multiple(Atom::Entry)
    

    include Enumerable

    def inspect
      "<#{@uri} entries: #{entries.length} title='#{title}'>"
    end

    def initialize feed_uri = nil, http = Atom::HTTP.new
      @entries = []
      @http = http

      if feed_uri
        @uri = feed_uri.to_uri
        self.base = feed_uri
      end

      super "feed"
    end

    def each &block
      @entries.each &block
    end

    # gets everything in the logical feed (could be a lot of stuff)
    #   implements part of http://www.ietf.org/internet-drafts/draft-nottingham-atompub-feed-history-05.txt
    def get_everything!
      self.update!
  
      prev = @prev
      while prev
        prev.update!

        self.merge_entries! prev
        prev = prev.prev
      end

      nxt = @next
      while nxt
        nxt.update!

        self.merge_entries! nxt
        nxt = nxt.next
      end

      self
    end

    # copies entries from another feed
    def merge_entries! other_feed
      other_feed.each do |entry|
        # TODO: add atom:source elements
        self << entry
      end
    end

    # merges important properties of another feed into this one
    def merge! other_feed
      [:id, :title, :subtitle, :updated, :rights].each { |p|
        self.send("#{p}=", other_feed.send("#{p}"))
      }

      [:links, :categories, :authors, :contributors].each do |p|
        other_feed.send("#{p}").each do |e|
          self.send("#{p}") << e
        end
      end

      merge_entries! other_feed
    end

    # merges this feed with another, returning a new feed
    def merge other_feed
      feed = self.clone

      feed.merge! other_feed
      
      feed
    end

    def update!
      raise(RuntimeError, "can't fetch without a uri.") unless @uri
     
      headers = {}
      headers["If-None-Match"] = @etag if @etag
      headers["If-Modified-Since"] = @last_modified if @last_modified

      res = @http.get(@uri, headers)

      if res.code == "304"
        # we're already all up to date
        return self
      elsif res.code != "200"
        raise "Unexpected HTTP response code: #{res.code}"
      elsif not res.content_type.match(/^application\/atom\+xml/)
        raise "Unexpected HTTP response Content-Type: #{res.content_type} (wanted application/atom+xml)"
      end

      @etag = res["Etag"] if res["Etag"]
      @last_modified = res["Last-Modified"] if res["Last-Modified"]

      xml = res.body

      coll = REXML::Document.new(xml)

      update_time = Time.parse(REXML::XPath.first(coll, "/atom:feed/atom:updated", { "atom" => Atom::NS } ).text)

      # the feed hasn't been updated, don't bother
      if self.updated and self.updated >= update_time
        return self
      end

      coll = coll.to_atom_feed(self.base.to_s)
      merge! coll
     
      link = coll.links.find { |l| l["rel"] = "next" and l["type"] == "application/atom+xml" }
      if link
        abs_uri = @uri + link["href"]
        @next = Feed.new(abs_uri.to_s, @http)
      end

      link = coll.links.find { |l| l["rel"] = "previous" and l["type"] == "application/atom+xml" } 
      if link
        abs_uri = @uri + link["href"]
        @prev = Feed.new(abs_uri.to_s, @http)
      end

      self
    end

    def << entry
      existing = entries.find do |e|
        e.id == entry.id
      end

      unless existing and not (entry.updated and existing.updated and (entry.updated > existing.updated))
        @entries << entry
      end
    end
  end
end

# this is here solely so you don't have to require it
require "atom/xml"
