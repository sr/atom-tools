#!/usr/bin/ruby

require "test/unit"

require "atom/yaml"
require "atom/xml"

require "atom/feed"

class AtomTest < Test::Unit::TestCase
  def test_feed_duplicate_id
    feed = Atom::Feed.new

    entry1 = get_entry
    entry1.id = "http://example.org/test"

    feed << entry1

    assert_equal(1, feed.entries.length)

    assert_block do
      feed.has_id? "http://example.org/test"
    end

    feed << entry1.dup
    assert_equal(1, feed.entries.length)
  end

  def test_tags
    entry = get_entry
    entry.tag_with "test tags"

    xml = get_elements entry

    assert_has_category(xml, "test")
    assert_has_category(xml, "tags")
  end

  def test_snarf_yaml
    yaml = """title: testing YAML
authors:
- name: Mr. Safe
  uri: http://example.com/
links:
- href: http://atomenabled.org/
content: not much here\
"""

    entry = Atom::Entry.from_yaml(yaml)

    assert_equal("testing YAML", entry.title.to_s)

    assert_equal(1, entry.authors.length)
    assert_equal("Mr. Safe", entry.authors.first.name)
    assert_equal("http://example.com/", entry.authors.first.uri)
    
    assert_equal(1, entry.links.length)
    assert_equal("http://atomenabled.org/", entry.links.first["href"])

    assert_equal("not much here", entry.content.to_s)
  end
 
  def assert_has_category xml, term
    assert_not_nil(REXML::XPath.match(xml, "/entry/category[@term = #{term}]"))
  end

  def assert_has_content_type xml, type
    assert_equal(type, xml.elements["/entry/content"].attributes["type"])
  end

  def get_entry
    Atom::Entry.new
  end

  def get_elements entry
    xml = entry.to_xml
 
    assert_equal(entry.to_s, xml.to_atom_entry.to_s) 
    
    base_check xml
    
    xml
  end

  def base_check xml
    assert_equal("entry", xml.root.name)
    assert_equal("http://www.w3.org/2005/Atom", xml.root.namespace)
  end
end
