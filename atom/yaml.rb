require "atom/entry"
require "yaml"

# all for converting to and from YAML. the format's described in README.
module Atom
  class Time
    def taguri; nil end
  end

  class Element < Hash
    def taguri; nil end

    def to_yaml_properties
      self.class.elements.find_all do |n,k,r|
        v = get(n)
        v and not (v.respond_to? :empty? and v.empty?)
      end.map { |n,k,r| "@#{n}" }
    end

    def to_yaml( opts = {} )
      YAML::quick_emit( object_id, opts ) do |out|
        out.map( taguri, to_yaml_style ) do |map|
          self.to_yaml_properties.each do |m|
            map.add( m[1..-1], instance_variable_get( m ) )
          end
        end
      end
    end
  end

  class AttrEl < Atom::Element
    def to_yaml( opts = {} )
      YAML::quick_emit( object_id, opts ) do |out|
        out.map( nil, to_yaml_style ) do |map|
          self.class.attrs.each do |n,r|
            map.add( n.to_s, self[n.to_s] ) if self[n.to_s]
          end
        end
      end
    end
  end

  class Text < Atom::Element
    def taguri; nil end
    def to_yaml( opts = {} )
      YAML::quick_emit( object_id, opts ) do |out|
        out.scalar(taguri, to_s, :quote2)
      end
    end
  end

  class Entry
    def to_yaml_type
      '!necronomicorp.com,2006/entry' # XXX why doesn't this show up?
    end
  
    def self.from_yaml yaml # XXX different name?
      hash = if yaml.kind_of?(Hash); yaml else YAML.load(yaml); end

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
