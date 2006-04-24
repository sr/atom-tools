#!/usr/bin/ruby

require "atom/pub-server"
require "webrick/httpserver"
require "atom/feed"

module Atom
  # @docs must implement [], []=, next_id! 
  # including servlet must implement gen_id, url_to_key, key_to_url, do_GET
  class MemoryCollection < WEBrick::HTTPServlet::AbstractServlet
    include Atom::AtomPub

    def initialize server, docs
      super

      @docs = docs
    end

    def gen_id key
      key
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

        feed.entries.first.to_s
      else
        key = url_to_key(req.request_uri.to_s)
        entry = @docs[key].to_atom_entry
        add_edit(entry, key)["href"] = key_to_url(req, key)
        entry.to_s
      end
    end
  end
end

h = WEBrick::HTTPServer.new(:Port => ARGV[0])

docs = {}
docs.instance_variable_set :@last_key, "0"

def docs.next_key!
  @last_key.next!
end

h.mount(ARGV[1], Atom::MemoryCollection, docs)

h.start
