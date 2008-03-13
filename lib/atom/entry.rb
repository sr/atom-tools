require "rexml/document"

require "atom/element"
require "atom/text"

module Atom
  class Control < Atom::Element
    attr_accessor :draft

    is_element PP_NS, :control

    on_parse [PP_NS, 'draft'] do |e,x|
      e.set(:draft, x.text == 'yes')
    end

    on_build do |e,x|
      unless (v = e.get(:draft)).nil?
        el = e.mk_elem(x, ['app', PP_NS], 'draft')
        el.text = (v ? 'yes' : 'no') 
      end
    end
  end

  module HasCategories
    def HasCategories.included(klass)
      klass.atom_elements :category, :categories, Atom::Category
    end

    # categorize the entry with each of an array or a space-separated
    #   string
    def tag_with(tags, delimiter = ' ')
      return if not tags or tags.empty?

      tag_list = unless tags.is_a?(String)
                   tags
                 else
                   tags = tags.split(delimiter)
                   tags.map! { |t| t.strip }
                   tags.reject! { |t| t.empty? }
                   tags.uniq
                 end

      tag_list.each do |tag|
        unless categories.any? { |c| c.term == tag }
          categories.new :term => tag
        end
      end
    end
  end

  module HasLinks
    def HasLinks.included(klass)
      klass.atom_elements :link, :links, Atom::Link
    end

    def find_link(criteria)
      self.links.find do |l|
        criteria.all? { |k,v| l.send(k) == v }
      end
    end
  end

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
    is_atom_element :entry

    # the master list of standard children and the types they map to
    atom_string :id

    atom_element :title, Atom::Title
    atom_element :summary, Atom::Summary
    atom_element :content, Atom::Content

    atom_element :rights, Atom::Rights

    # element :source, Atom::Feed  # XXX complicated, eg. serialization

    atom_time :published
    atom_time :updated
    time ['app', PP_NS], :edited

    atom_elements :author, :authors, Atom::Author
    atom_elements :contributor, :contributors, Atom::Contributor

    element ['app', PP_NS], :control, Atom::Control

    include HasCategories
    include HasLinks

    atom_link :edit_url, :rel => 'edit'

    def inspect # :nodoc:
      "#<Atom::Entry id:'#{self.id}'>"
    end

    def draft
      control and control.draft
    end

    alias :draft? :draft

    def draft!
      self.draft = true
    end

    def draft= is_draft
      unless control
        instance_variable_set '@control', Atom::Control.new
      end
      control.draft = is_draft
    end
  end
end
