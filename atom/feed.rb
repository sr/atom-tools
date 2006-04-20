require "atom/entry"
require "atom/http"

module Atom
  class Feed
    attr_reader :uri, :entries, :prev, :next

    include Enumerable

    def initialize feed_uri = nil, http = Atom::HTTP.new
      @entries = []
      @http = http

      if feed_uri
        @uri = if feed_uri.kind_of? URI
          feed_uri
        else
          URI.parse(feed_uri)
        end
      end
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

        self.merge! prev
        prev = prev.prev
      end

      nxt = @next
      while nxt
        nxt.update!

        self.merge! nxt
        nxt = nxt.next
      end

      self
    end

    def merge! other_feed
      other_feed.each do |entry|
        # TODO: add atom:source elements
        self << entry
      end
    end

    # merges this feed with another, returning a new feed
    def merge other_feed
      feed = self.clone

      feed.merge! other_feed
      
      feed
    end

    # tests to see if this feed already has an id in it
    def has_id? an_id
      entries.find do |entry|
        entry.id == an_id
      end
    end

    def parse_from(xml)
      coll = REXML::Document.new(xml)

      REXML::XPath.each(coll, "/atom:feed/atom:entry", { "atom" => Atom::NS } ) do |x|
        self << x.to_atom_entry
      end
      
      next_feed = REXML::XPath.first(coll, "/atom:feed/atom:link[@rel='next']/@href", { "atom" => Atom::NS } )

      if next_feed
        abs_uri = @uri + next_feed.to_s
        @next = Feed.new(abs_uri.to_s, @http)
      end

      prev_feed = REXML::XPath.first(coll, "/atom:feed/atom:link[@rel='previous']/@href", { "atom" => Atom::NS } )

      if prev_feed
        abs_uri = @uri + prev_feed.to_s
        @prev = Feed.new(abs_uri.to_s, @http)
      end

      self
    end

    def update!
      raise(RuntimeError, "can't fetch without a uri.") unless @uri
      
      res = @http.get(@uri)

      if res.code != "200"
        raise RuntimeError, "Unexpected HTTP response code: #{res.code}"
      elsif not res.content_type.match(/^application\/atom\+xml/)
        raise RuntimeError, "Unexpected HTTP response Content-Type: #{res.content_type}"
      end

      parse_from(res.body)
    end

    def << entry
      # check that we're not adding duplicate entries
      unless self.has_id? entry.id
        @entries << entry
      end
    end
  end
end
