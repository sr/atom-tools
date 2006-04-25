require "atom/entry"
require "uri"

module REXML
  class Document
    def to_atom_entry base = ""
      self.root.to_atom_entry base
    end
  end
  class Element
    # get the first element matching './/atom:<name>'
    def get_atom_element name
      XPath.first(self, ".//atom:#{name}", { "atom" => Atom::NS })
    end
    
    # get an array of elements matching './/atom:<name>'
    def get_atom_elements name
      XPath.match(self, ".//atom:#{name}", { "atom" => Atom::NS })
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
          # content is out-of-line
          entry.send( "#{name}=".to_sym, "a")     # XXX this is really dumb
          entry.send(name.to_sym)["src"] = src
        elsif type == "xhtml"
          # content is the serialized content of the <div> wrapper
          entry.send( "#{name}=".to_sym, text.elements[1].children.to_s )
        else
          # content is the serialized content of the <content> wrapper
          entry.send( "#{name}=", text.children.to_s)
        end
        
        if text.attributes["xml:base"]
          entry.send(name.to_sym).base = text.attributes["xml:base"]
        end

        if type and type != "text"
          entry.send(name.to_sym)["type"] = type
        end
      end
    end

    # REXML Stream parsing API might be more suited to the task?
    def to_atom_entry base = ""
      unless self.name == "entry" and self.namespace == Atom::NS
        raise TypeError, "this isn't an atom:entry! (name: #{self.name}, ns: #{self.namespace})"
      end

      entry = Atom::Entry.new

      entry.base = base

      if attributes["xml:base"]
        entry.base = attributes["xml:base"]
      end

      # Text constructs
      entry.class.elements.find_all { |n,k,r| k.ancestors.member? Atom::Text }.
        each do |n,k,r|
          fill_text_construct(entry, n)
      end

      ["id", "published", "updated"].each do |name|
        entry.send("#{name}=".to_sym, get_atom_text(name))
      end

      ["author", "contributor"].each do |type|
        get_atom_elements(type).each do |elem|
          person = entry.send("#{type}s".to_sym).new
       
          ["name", "uri", "email"].each do |name|
            person.send("#{name}=".to_sym, elem.get_atom_text(name))
          end
        end
      end

      {"link" => entry.links, "category" => entry.categories}.each do |k,v|
        get_atom_elements(k).each do |elem|
          thing = v.new

          thing.class.attrs.each do |name,req|
            value = elem.ns_attr name.to_s
            if value and name == :href
              thing[name.to_s] = (URI.parse(entry.base) + value).to_s
            elsif value
              thing[name.to_s] = value
            end
          end
        end
      end
      
      # extension elements
      get_extensions.each do |elem|
        entry.extensions << elem.dup # otherwise they get removed from the doc
      end

      entry
    end
  end
end
