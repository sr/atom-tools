require "test/unit"
require "atom/entry"

class ConstructTest < Test::Unit::TestCase
  def test_text_construct_text
    entry = Atom::Entry.new

    assert_nil(entry.title)
    assert_equal("", entry.title.to_s)

    entry.title = "<3"

    assert_equal "text", entry.title["type"]
    assert_equal "<3", entry.title.to_s
    assert_equal "&lt;3", entry.title.html

    assert_equal "'<3'#text", entry.title.inspect

    title = entry.to_xml.root.children.first
    assert_equal "<3", title.text
  end

  def test_text_construct_html
    entry = Atom::Entry.new

=begin
    entry.title = "<3"
    entry.title["type"] = "html"

    assert_equal "html", entry.title["type"]
    assert_equal "<3", entry.title.to_s
    assert_equal "&lt;3", entry.title.html
    
    title = entry.to_xml.root.children.first
    assert_equal "<3", title.text
=end

    entry.title = "<p>pi &lt; 4?"
    entry.title["type"] = "html"

    assert_equal "<p>pi &lt; 4?", entry.title.to_s
    assert_equal "<p>pi &lt; 4?", entry.title.html
  end

  def test_text_construct_xhtml
    entry = Atom::Entry.new

    entry.title = "<3"
    assert_raises(RuntimeError) { entry.title["type"] = "xhtml" }
   
    assert_raises(RuntimeError) do
      entry.title["type"] = "application/xhtml+xml"
    end

    entry.title = REXML::Document.new("<div xmlns='http://www.w3.org/1999/xhtml'>&lt;3</div>").root
    entry.title["type"] = "xhtml"

    assert_equal "&lt;3", entry.title.to_s
    assert_equal "&lt;3", entry.title.html

    entry.title = "&lt;3"
    entry.title["type"] = "xhtml"

    assert_equal "&lt;3", entry.title.to_s
    assert_equal "&lt;3", entry.title.html

    entry.title = "<em>goodness</em> gracious"
    entry.title["type"] = "xhtml"

    assert_equal "<em>goodness</em> gracious", entry.title.to_s
    assert_equal "<em>goodness</em> gracious", entry.title.html
  end

  def test_content
    entry = Atom::Entry.new

    entry.content = ""
    entry.content["src"] = "http://example.com/example.svg"
    entry.content["type"] = "image/svg+xml"

    assert_equal("", entry.content.to_s)
  end

  require "date"
  def test_date_construct
    today = Date.today
    time = Atom::Time.new today

    assert_match(/^#{today}T00:00:00/, time.to_s)
  end
end
