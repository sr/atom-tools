require "atom/entry"
require "atom/element"
require "atom/http"

module Atom
  class Feed < Atom::Element
    attr_reader :uri, :prev, :next

    element :id, String, true
    element :title, Atom::Text, true
    element :subtitle, Atom::Text
   
    element :updated, Atom::Time, true

    element :links, Atom::Multiple(Atom::Link)
    element :categories, Atom::Multiple(Atom::Category)

    element :authors, Atom::Multiple(Atom::Author)
    element :contributors, Atom::Multiple(Atom::Contributor)

    element :generator, String # uri and version attributes
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

    def parse_from(xml)
      coll = REXML::Document.new(xml)

      update_time = Time.parse(REXML::XPath.first(coll, "/atom:feed/atom:updated", { "atom" => Atom::NS } ).text)

      unless self.updated and not (update_time > self.updated)
        REXML::XPath.each(coll, "/atom:feed/atom:entry", { "atom" => Atom::NS } ) do |x|
          self << x.to_atom_entry(self.base.to_s)
        end
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
      existing = entries.find do |e|
        e.id == entry.id
      end

      unless existing and not (entry.updated and existing.updated and (entry.updated > existing.updated))
        @entries << entry
      end
    end
  end
end
