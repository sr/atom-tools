require "rexml/document"

require "atom/element"
require "atom/text"

module Atom
  NS = "http://www.w3.org/2005/Atom"
  PP_NS = "http://www.w3.org/2007/app"

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
  #   author = entry.authors.new :name => "Captain Kangaroo", :email => "kanga@example.net"
  #
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
      super

      # XXX I don't think I've ever actually used this
      yield self if block_given?
    end

    # parses XML into an Atom::Entry
    #
    # +base+ is the absolute URI the document was fetched from
    # (if there is one)
    def self.parse xml, base = ""
      if xml.respond_to? :to_atom_entry
        xml.to_atom_entry(base)
      elsif xml.respond_to? :read
        self.parse(xml.read, base)
      else
        begin
          REXML::Document.new(xml.to_s).to_atom_entry(base)
        rescue REXML::ParseException => e
          raise Atom::ParseError, e.message
        end
      end
    end

    def inspect # :nodoc:
      "#<Atom::Entry id:'#{self.id}'>"
    end

    # declare that this entry has updated.
    #
    # (note that this is different from Atom::Feed#update!)
    def updated!
      self.updated = Time.now
    end

    # declare that this entry has been edited 
    def edited!
      self.edited= Time.now
    end

    # categorize the entry with each of an array or a space-separated
    #   string
    def tag_with(tags, delimiter = ' ')
      return if tags.nil? || tags.empty?
      tag_list = tags.is_a?(String) ? tags.split(delimiter) : tags
      tag_list.reject! { |t| t !~ /\S/ }
      tag_list.map! { |t| t.strip }
      tag_list.uniq!
      tag_list.each do |tag|
        unless categories.any? { |category| category['term'] == tag }
          categories.new['term'] = tag
        end
      end
    end

    # the @href of an entry's link[@rel="edit"]
    def edit_url
      begin
        edit_link = self.links.find do |link|
          link["rel"] == "edit"
        end

        edit_link["href"]
      rescue
        nil
      end
    end

    # NOTE: check that url is a valid URI?
    def edit_url=(url)
      link = Atom::Link.new({:href => url, :rel => 'edit'})
      begin
        edit_link = self.links.find { |link| link['rel'] = 'edit' }
        edit_link['href'] = url
      rescue
        links << link
      end
    end

    def edited=(time)
      element = REXML::XPath.first(extensions, 'app:edited', {'app' => PP_NS})
      unless element
        element = REXML::Element.new('edited')
        element.add_namespace Atom::PP_NS
        extensions << element 
      end
      element.text = Atom::Time.new(time) 
    end

    def edited
      element = REXML::XPath.first(extensions, 'app:edited', {'app' => PP_NS})
      element ? Atom::Time.new(element.text) : nil
    end

    def draft
      elem = REXML::XPath.first(extensions, "app:control/app:draft", {"app" => PP_NS})

      (elem && elem.text == "yes") ? true : false
    end

    def draft?; draft end

    def draft= is_draft
      nses = {"app" => PP_NS}
      draft_e = REXML::XPath.first(extensions, "app:control/app:draft", nses)
      control_e = REXML::XPath.first(extensions, "app:control", nses)

      if is_draft and not draft
        unless draft_e
          unless control_e
            control_e = REXML::Element.new("control")
            control_e.add_namespace PP_NS

            extensions << control_e
          end

          draft_e = REXML::Element.new("draft")
          control_e << draft_e
        end

        draft_e.text = "yes"
      elsif not is_draft and draft
        draft_e.remove
        control_e.remove if control_e.elements.empty?
      end

      is_draft
    end

    def draft!; self.draft = true end

# XXX this needs a test suite before it can be trusted.
=begin
    # tests the entry's validity
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
=end
  end
end

# this is here solely so that you don't have to require it
require "atom/xml"
