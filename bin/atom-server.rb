#!/usr/bin/ruby

# syntax: ./atom-server <base-url>

require "atom/pub-server"
require "webrick/httpserver"
require "atom/feed"

module Atom
  # @docs must implement [], []=, next_id!, delete
  # including servlet must implement gen_id, url_to_key, key_to_url, do_GET
  class MemoryCollection < WEBrick::HTTPServlet::AbstractServlet
    include Atom::AtomPub

    def initialize server, docs
      super

      @docs = docs
    end

    def gen_id key
      "tag:#{$base_uri.host},#{Time.now.year}:/atom/#{key}"
    end
    
    def key_to_url req, key
      req.script_name + "/" + key
    end

    def url_to_key url
      url.split("/").last
    end

    def add_edit entry, key
      edit = entry.links.new
      edit["rel"] = "edit"
      edit
    end

    def do_GET req, res
      res.body = if req.path_info.empty? or req.path_info == "/"
        feed = Atom::Feed.new
        
        @docs.each do |key,doc|
          entry = doc.to_atom_entry
          add_edit(entry, key)["href"] = key_to_url(req, key)
          feed << entry
        end

        feed.to_s
      else
        key = url_to_key(req.request_uri.to_s)
        entry = @docs[key].to_atom_entry
        add_edit(entry, key)["href"] = key_to_url(req, key)
        entry.to_s
      end

      res.content_type = "application/atom+xml"
    end
  end

  class Introspection < WEBrick::HTTPServlet::AbstractServlet
    def do_GET(req, res)
      doc = REXML::Document.new

      service = REXML::Element.new("service", doc)
      service.add_namespace "http://purl.org/atom/app#"

      workspace = REXML::Element.new("workspace", service)
      workspace.attributes["title"] = "unimportant"

      elem = REXML::Element.new("collection", workspace)
      elem.attributes["href"] = $base_uri + "/atom"
      elem.attributes["title"] = "atom-tools memory collection"
      REXML::Element.new("member-type", elem).text = "entry"

      res['Content-Type'] = "application/atomserv+xml"
      res.body = doc.to_s
    end
  end
end

$base_uri = URI.parse(ARGV[0])

s = WEBrick::HTTPServer.new(:Port => $base_uri.port)

docs = {}
docs.instance_variable_set :@last_key, "0"

def docs.next_key!
  @last_key.next!
end

s.mount("/atom", Atom::MemoryCollection, docs)
s.mount("/", Atom::Introspection)

trap("INT") do
  s.shutdown
end

s.start
