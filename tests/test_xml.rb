require "test/unit"

require "atom/entry"
require "atom/xml"

class AtomTest < Test::Unit::TestCase
  def test_text_type_text
    entry = get_entry
    
    entry.title = "Atom-drunk pirates run amok!"
    assert_equal("text", entry.title["type"])

    xml = get_elements entry
    
    assert_equal("Atom-drunk pirates run amok!", xml.elements["/entry/title"].text)
  end

  def test_text_type_html
    entry = get_entry

    entry.title = "Atom-drunk pirates<br>run amok!"
    entry.title["type"] = "html"

    xml = get_elements entry

    assert_equal("Atom-drunk pirates<br>run amok!", xml.elements["/entry/title"].text)
    assert_equal("html", xml.elements["/entry/title"].attributes["type"])
  end

  def test_text_type_xhtml
    entry = get_entry

    entry.title = REXML::Document.new("Atom-drunk pirates <em>run amok</em>!")
    entry.title["type"] = "xhtml"

    xml = get_elements entry

    assert_equal(XHTML::NS, xml.elements["/entry/title/div"].namespace)
    assert_equal("run amok", xml.elements["/entry/title/div/em"].text)
  end

  def test_text_malformed_xhtml
    entry = get_entry

    entry.title = "A malformed title & more!"
    entry.title["type"] = "xhtml"

    # things are only parsed when it's to be serialized
    assert_raises(REXML::ParseException) do
      entry.to_s
    end
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

  def test_extensive_parsing
str = '<entry xmlns="http://www.w3.org/2005/Atom">
  <title>Atom draft-07 snapshot</title>
  <link rel="alternate" type="text/html"
    href="http://example.org/2005/04/02/atom"/>
  <link rel="enclosure" type="audio/mpeg" length="1337"
    href="http://example.org/audio/ph34r_my_podcast.mp3"/>
  <id>tag:example.org,2003:3.2397</id>
  <updated>2005-07-31T12:29:29Z</updated>
  <published>2003-12-13T08:29:29-04:00</published>
  <author>
    <name>Mark Pilgrim</name>
    <uri>http://example.org/</uri>
    <email>f8dy@example.com</email>
  </author>
  <contributor>
    <name>Sam Ruby</name>
  </contributor>
  <contributor>
    <name>Joe Gregorio</name>
  </contributor>
  <content type="xhtml" xml:lang="en"
    xml:base="http://diveintomark.org/">
    <div xmlns="http://www.w3.org/1999/xhtml">
      <p><i>[Update: The Atom draft is finished.]</i></p>
    </div>
  </content>
</entry>'

    entry = REXML::Document.new(str).to_atom_entry 
  
    assert_equal("Atom draft-07 snapshot", entry.title.to_s)
    assert_equal("tag:example.org,2003:3.2397", entry.id)
  
    assert_equal(Time.parse("2005-07-31T12:29:29Z"), entry.updated)
    assert_equal(Time.parse("2003-12-13T08:29:29-04:00"), entry.published)

    assert_equal(2, entry.links.length)
    assert_equal("alternate", entry.links.first["rel"])
    assert_equal("text/html", entry.links.first["type"])
    assert_equal("http://example.org/2005/04/02/atom", entry.links.first["href"])

    assert_equal("enclosure", entry.links.last["rel"])
    assert_equal("audio/mpeg", entry.links.last["type"])
    assert_equal("1337", entry.links.last["length"])
    assert_equal("http://example.org/audio/ph34r_my_podcast.mp3", entry.links.last["href"])

    assert_equal(1, entry.authors.length)
    assert_equal("Mark Pilgrim", entry.authors.first.name)
    assert_equal("http://example.org/", entry.authors.first.uri)
    assert_equal("f8dy@example.com", entry.authors.first.email)
    
    assert_equal(2, entry.contributors.length)
    assert_equal("Sam Ruby", entry.contributors.first.name)
    assert_equal("Joe Gregorio", entry.contributors.last.name)
  
    assert_equal("xhtml", entry.content["type"])
   
    assert_match("<p><i>[Update: The Atom draft is finished.]</i></p>", 
                 entry.content.to_s)
    
    # XXX unimplemented
    assert_equal("http://diveintomark.org/", entry.content.base)
    assert_equal("en", entry.content.lang)
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
