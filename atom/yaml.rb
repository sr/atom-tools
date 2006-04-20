require "atom/entry"
require "yaml"

# all for converting to and from YAML. the format's described in README.
#
# limitations:
# - content/@src isn't handled
module Atom
  class Element < Hash
    def to_yaml( opts = {} )
      YAML::quick_emit( object_id, opts ) do |out|
        out.map( nil, to_yaml_style ) do |map|
          self.class.attrs.each do |attr|
            value = self[attr]
            map.add( attr, value ) if value
          end
        end
      end
    end
  end

  class Person
    def to_yaml( opts = {} )
      YAML::quick_emit( object_id, opts ) do |out|
        out.map( nil, to_yaml_style ) do |map|
          map.add("name", @name) if @name
          map.add("uri", @uri) if @uri
          map.add("email", @email) if @email
        end
      end
    end
  end

  class Entry
    def to_yaml( opts = {} )
      YAML::quick_emit( object_id, opts ) do |out|
        out.map( nil, to_yaml_style ) do |map|
          self.class.element.each do |name,kind,req|
            next if name == "content"
            v = get name
            map.add( name, v ) if v
          end
         
          if content
            map.add( "type", content["type"] )
            map.add( "content", content.to_s )
          end
        end
      end
    end

    def self.from_yaml yaml
      hash = if yaml.kind_of? Hash
        yaml
      else
        YAML.load(yaml)
      end

      entry = Atom::Entry.new

      entry.title   = hash["title"]
      entry.summary = hash["summary"]
     
      elem_constructs = {"authors" => entry.authors, "contributors" => entry.contributors, "links" => entry.links, "categories" => entry.categories}

      elem_constructs.each do |type,ary|
        hash[type] ||= []
        
        hash[type].each do |yelem|
          elem = ary.new

          elem.class.attrs.each do |attrb,req|
            elem[attrb.to_s] = yelem[attrb.to_s]
          end
    
          elem.class.elements.each do |name,kind,req|
            elem.send("#{name}=".to_sym, yelem[name.to_s])
          end
        end
      end

      # this adds more categories, and could cause conflicts
      entry.tag_with hash["tags"]
      entry.content = hash["content"]
      entry.content["type"] = hash["type"] if hash["type"]

      entry
    end
  end
end
