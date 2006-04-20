#!/usr/bin/ruby

require "test/unit"

require "atom/entry"
require "atom/yaml"
require "atom/xml"

require "atom/feed"

class AtomTest < Test::Unit::TestCase
  def test_empty_entry
    get_elements get_entry
  end

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

  def test_title
    entry = get_entry
    entry.title = "frobniz"

    xml = get_elements entry

    assert_equal("frobniz", xml.elements["/entry/title"].text)
  end

  def test_id
    entry = get_entry
    entry.id = "http://example.org/app-id"

    xml = get_elements entry

    assert_equal("http://example.org/app-id", xml.elements["/entry/id"].text)
  end


  def test_link
    entry = get_entry
    link = entry.links.new
    
    link["href"] = "http://example.com"
    link["rel"] = "test"

    xml = get_elements entry
    
    assert_equal("http://example.com", xml.elements["/entry/link/@href"].to_s)
    assert_equal("test", xml.elements["/entry/link/@rel"].to_s)
  end

  def test_author
    entry = get_entry
    a = entry.authors.new
    
    a.name= "Brendan Taylor"
    a.uri = "http://necronomicorp.com/blog/"

    xml = get_elements entry

    assert_equal("http://necronomicorp.com/blog/", xml.elements["/entry/author/uri"].text)
    assert_equal("Brendan Taylor", xml.elements["/entry/author/name"].text)
    assert_nil(xml.elements["/entry/author/email"])
  end

  def test_tags
    entry = get_entry
    entry.tag_with "test tags"

    xml = get_elements entry

    assert_has_category(xml, "test")
    assert_has_category(xml, "tags")
  end

  def test_updated
    entry = get_entry
    entry.updated = "1970-01-01"
    entry.content = "blah"

    assert_instance_of(Time, entry.updated)

    xml = get_elements entry

    assert_match(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/, xml.elements["//updated"].text, "atom:updated isn't in xsd:datetime format")

    entry.update!

    assert((Time.parse("1970-01-01") < entry.updated), "<updated/> is not updated")
  end

  def test_xhtml
    entry = get_entry
    entry.content = "<p>xhtml test</p>"
    entry.content["type"] = "xhtml"

    xml = get_elements entry

    assert_has_content_type(xml, "xhtml")
    
    div = xml.elements["/entry/content"].elements[1]
    assert_equal(XHTML::NS, div.namespace)
    assert_equal("div", div.name)
  end

  def test_text
    test_default_content_type
  end

  def test_out_of_line
    entry = get_entry

    entry.content = "this shouldn't appear"
    entry.content["src"] = 'http://example.org/test.png'
    entry.content["type"] = "image/png"

    xml = get_elements(entry)

    assert_nil(xml.elements["/entry/content"].text)
    assert_equal("http://example.org/test.png", xml.elements["/entry/content"].attributes["src"])
    assert_equal("image/png", xml.elements["/entry/content"].attributes["type"])
  end

  def test_default_content_type
    entry = get_entry
    entry.content = "<p/>"

    xml = get_elements entry

    assert_has_content_type(xml, "text")
    assert_equal("<p/>", xml.elements["/entry/content"].text)
  end

  def test_extensions
    entry = get_entry

    assert(entry.extensions.children.empty?)

    element = REXML::Element.new("test")
    element.add_namespace "http://purl.org/"

    entry.extensions << element

    xml = get_elements entry

    assert_equal(REXML::Element, xml.elements["/entry/test"].class)
    assert_equal("http://purl.org/", xml.elements["/entry/test"].namespace)
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
 
  def test_snarf_xml
    xml = "<entry xmlns='http://www.w3.org/2005/Atom'>
<id>http://example.org/app-id</id>
<title>testing XML</title>
<author><name>Mr. Safe</name><uri>http://example.com/</uri></author>
<link href='http://atomenabled.org/'/>
<content>not much here</content>
</entry>"

    entry = REXML::Document.new(xml).to_atom_entry
 
    assert_equal("http://example.org/app-id", entry.id)
    assert_equal("testing XML", entry.title.to_s)

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
