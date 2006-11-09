require "rexml/document"

require "atom/element"
require "atom/text"

module Atom
  NS = "http://www.w3.org/2005/Atom"

  # An individual entry in a feed. As an Atom::Element, it can be
  # manipulated using accessors for each of its child elements. You
  # should be able to set them using an instance of any class that
  # makes sense
  #
  # Entries have the following children:
  #
  # id:: a universally unique IRI which permanently identifies the entry
  # title:: a human-readable title (Atom::Text)
  # content:: contains or links to the content of an entry (Atom::Content)
  # rights:: information about rights held in and over an entry (Atom::Text)
  # source:: the source feed's metadata (unimplemented)
  # published:: a Time "early in the life cycle of an entry"
  # updated:: the most recent Time an entry was modified in a way the publisher considers significant
  # summary:: a summary, abstract or excerpt of an entry (Atom::Text)
  #
  # There are also +categories+, +links+, +authors+ and +contributors+,
  # each of which is an Array of its respective type and can be used
  # thusly:
  #
  #   author = entry.authors.new
  #   author.name = "Captain Kangaroo"
  class Entry < Atom::Element
    # the master list of standard children and the types they map to
    element :id, String, true
    element :title, Atom::Text, true
    element :content, Atom::Content, true
    
    element :rights, Atom::Text
    # element :source, Atom::Feed  # complicated, eg. serialization
    
    element :authors, Atom::Multiple(Atom::Author)
    element :contributors, Atom::Multiple(Atom::Contributor)
    
    element :categories, Atom::Multiple(Atom::Category)
    element :links, Atom::Multiple(Atom::Link)
    
    element :published, Atom::Time
    element :updated, Atom::Time, true
    
    element :summary, Atom::Text

    def initialize # :nodoc:
      super "entry"
     
      # XXX I don't think I've ever actually used this
      yield self if block_given?
    end

    def inspect # :nodoc:
      "#<Atom::Entry id:'#{self.id}'>"
    end

    def update!
      self.updated = Time.now
    end

    # categorize the entry based on a space-separated string
    def tag_with string
      return if string.nil?

      string.split.each do |tag|
        categories.new["term"] = tag
      end
    end

    # tests the entry's validity
    # XXX this needs a test suite before it can be trusted.
    def valid?
      self.class.required.each do |element|
        unless instance_variable_get "@#{element}"
          return [ false, "required element atom:#{element} missing" ]
        end
      end

      if @authors.length == 0
        return [ false, "required element atom:author missing" ]
      end

      alternates = @links.find_all do |link|
        link["rel"] == "alternate"
      end

      unless @content or alternates
          return [ false, "no atom:content or atom:link[rel='alternate']" ]
      end

      alternates.each do |link|
        if alternates.find do |x|
          not x == link and 
            x["type"] == link["type"] and 
            x["hreflang"] == link["hreflang"]
          end
         
          return [ false, 'more than one atom:link with a rel attribute value of "alternate" that has the same combination of type and hreflang attribute values.' ]
        end
      end

      type = @content["type"]

      base64ed = (not ["", "text", "html", "xhtml"].member? type) and 
        type.match(/^text\/.*/).nil? and  # not text
        type.match(/.*[\+\/]xml$/).nil?   # not XML

      if (@content["src"] or base64ed) and not summary
        return [ false, "out-of-line or base64ed atom:content and no atom:summary" ]
      end

      true
    end
  end
end

# this is here solely so that you don't have to require it
require "atom/xml"
