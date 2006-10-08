require "atom/entry"

class ConstructTest < Test::Unit::TestCase
  def test_text_construct
    entry = Atom::Entry.new

    assert_nil(entry.title)
    assert_equal("", entry.title.to_s)

    entry.title = "<3"
    assert_equal "text", entry.title["type"]
    assert_equal "<3", entry.title.to_s

    title = entry.to_xml.root.children.first
    assert_equal "<3", title.text

    entry.title["type"] = "html"
    assert_equal "html", entry.title["type"]
    assert_equal "<3", entry.title.to_s
    
    title = entry.to_xml.root.children.first
    assert_equal "<3", title.text

    # XXX less generic errors would be good
    assert_raises(RuntimeError) { entry.title["type"] = "xhtml" }
   
    assert_raises(RuntimeError) do
      entry.title["type"] = "application/xhtml+xml"
    end
  end

  def test_content
    entry = Atom::Entry.new

    entry.content = ""
    entry.content["src"] = "http://example.com/example.svg"
    entry.content["type"] = "image/svg+xml"

    assert_equal("", entry.content.to_s)
  end
end
