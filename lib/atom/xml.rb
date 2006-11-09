require "atom/entry"
require "atom/feed"
require "uri"

module REXML # :nodoc: all
  class Document
    def to_atom_entry base = ""
      self.root.to_atom_entry base
    end
    def to_atom_feed base = ""
      self.root.to_atom_feed base
    end
  end
  class Element
    def get_atom_element name
      XPath.first(self, "./atom:#{name}", { "atom" => Atom::NS })
    end
    
    def each_atom_element name
      XPath.each(self, "./atom:#{name}", { "atom" => Atom::NS }) do |elem|
        yield elem
      end
    end
   
    def get_extensions
      # XXX also look for attributes
      children.find_all { |child| child.respond_to? :namespace and child.namespace != Atom::NS }
    end
   
    # get the text content of a descendant element in the Atom namespace
    def get_atom_text name
      elem = get_atom_element name
      if elem
        elem.text
      else
        nil
      end
    end
  
    # a workaround for the odd way in which REXML handles namespaces
    # returns the value of the attribute 'name' in the same namespace as this element
    def ns_attr name
      if not self.prefix.empty?
        attr = self.prefix + ":" + name
      else
        attr = name
      end

      self.attributes[attr]
    end
   
    def fill_text_construct(entry, name)
      text = get_atom_element(name)
      if text
        type = text.ns_attr("type")
        src = text.ns_attr("src")

        if src                          # XXX ignore src= outside of <content/>
          # the only content is out of line
          entry.send( "#{name}=".to_sym, "")
          entry.send(name.to_sym)["src"] = src
        elsif type == "xhtml"
          div = XPath.first(text, "./xhtml:div", { "xhtml" => XHTML::NS })
          unless div
            raise "Refusing to parse type='xhtml' with no <div/> wrapper"
          end

          # content is the serialized content of the <div> wrapper
          entry.send( "#{name}=".to_sym, div )
        else
          raw = text.text
          entry.send( "#{name}=", raw )
        end
        
        if text.attributes["xml:base"]
          entry.send(name.to_sym).base = text.attributes["xml:base"]
        end

        if type and type != "text"
          entry.send(name.to_sym)["type"] = type
        end
      end
    end

    def fill_elem_element(top, kind)
      each_atom_element(kind) do |elem|
        person = top.send("#{kind}s".to_sym).new
     
        ["name", "uri", "email"].each do |name|
          person.send("#{name}=".to_sym, elem.get_atom_text(name))
        end
      end
    end

    def fill_attr_element(top, array, kind)
      each_atom_element(kind) do |elem|
        thing = array.new

        thing.class.attrs.each do |name,req|
          value = elem.ns_attr name.to_s
          if value and name == :href
            thing[name.to_s] = (URI.parse(top.base) + value).to_s
          elsif value
            thing[name.to_s] = value
          end
        end
      end
    end

    def to_atom_entry base = ""
      unless self.name == "entry" and self.namespace == Atom::NS
        raise TypeError, "this isn't an atom:entry! (name: #{self.name}, ns: #{self.namespace})"
      end

      entry = Atom::Entry.new

      entry.base = if attributes["xml:base"]
        (URI.parse(base) + attributes["xml:base"]).to_s
      else
        # go with the URL we were passed in
        base
      end

      # Text constructs
      entry.class.elements.find_all { |n,k,r| k.ancestors.member? Atom::Text }.each do |n,k,r|
        fill_text_construct(entry, n)
      end

      ["id", "published", "updated"].each do |name|
        entry.send("#{name}=".to_sym, get_atom_text(name))
      end

      ["author", "contributor"].each do |type|
        fill_elem_element(entry, type)
      end

      {"link" => entry.links, "category" => entry.categories}.each do |k,v|
        fill_attr_element(entry, v, k)
      end
      
      # extension elements
      get_extensions.each do |elem|
        entry.extensions << elem.dup # otherwise they get removed from the doc
      end

      entry
    end

    def to_atom_feed base = ""
      unless self.name == "feed" and self.namespace == Atom::NS
        raise TypeError, "this isn't an atom:feed! (name: #{self.name}, ns: #{self.namespace})"
      end

      feed = Atom::Feed.new
      
      feed.base = if attributes["xml:base"]
        (URI.parse(base) + attributes["xml:base"]).to_s
      else
        # go with the URL we were passed in
        base
      end
      
      # Text constructs
      feed.class.elements.find_all { |n,k,r| k.ancestors.member? Atom::Text }.each do |n,k,r|
        fill_text_construct(feed, n)
      end

      ["id", "updated", "generator", "icon", "logo"].each do |name|
        feed.send("#{name}=".to_sym, get_atom_text(name))
      end

      ["author", "contributor"].each do |type|
        fill_elem_element(feed, type)
      end

      {"link" => feed.links, "category" => feed.categories}.each do |k,v|
        fill_attr_element(feed, v, k)
      end
     
      each_atom_element("entry") do |elem|
        feed << elem.to_atom_entry(feed.base)
      end

      get_extensions.each do |elem|
        # have to duplicate them, or they'll get removed from the doc
        feed.extensions << elem.dup
      end

      feed
    end
  end
end
