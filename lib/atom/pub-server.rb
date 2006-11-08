require "rexml/document"
require "atom/entry"

module Atom
  module AtomPub
    # general sanitization of the element before it's finalized
    def prep_entry doc, key
      entry = doc.to_atom_entry
      
      entry.links.each do |link|
        if link["rel"] == "edit" or link["rel"] == "alternate"
          entry.links.delete link
        end
      end
      
      entry.id = gen_id(key)

      entry.to_xml
    end

    def do_POST req, res
      doc = REXML::Document.new(req.body)

      key = @docs.next_key!

      xml = prep_entry(doc, key)
      @docs[key] = xml

      res.status = 201 # Created
      res["Location"] = key_to_url(req, key)
      res.content_type = "application/atom+xml"
      res.body = xml.to_s
    end

    def do_PUT req, res
      doc = REXML::Document.new(req.body)
      # XXX check that the key is valid
      key = url_to_key(req.request_uri.to_s)
        
      xml = prep_entry(doc, key)
      @docs[key] = xml

      res.content_type = "application/atom+xml"
      res.body = xml.to_s
    end

    def do_DELETE req, res
      # XXX check that the key is valid
      key = url_to_key(req.request_uri.to_s)
      entry = @docs.delete key

      res.content_type = "application/atom+xml"
      res.body = entry.to_s
    end
  end
  
end
