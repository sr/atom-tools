require "test/unit"

require "atom/service"

class FakeHTTP
  Response = Struct.new(:body, :code, :content_type)

  def initialize table, mime_type
    @table = table
    @mime_type = mime_type
  end
  def get url
    res = Response.new
    res.body = @table[url.to_s]
    res.code = 200.to_s
    res.content_type = @mime_type
    res
  end
end

class AtomProtocolTest < Test::Unit::TestCase
  def test_introspection
    doc = <<END
<service xmlns="http://www.w3.org/2007/app"
  xmlns:atom="http://www.w3.org/2005/Atom">
  <workspace>
    <atom:title>My Blog</atom:title>
    <collection href="http://example.org/myblog/entries">
      <atom:title>Entries</atom:title>
    </collection>
    <collection href="http://example.org/myblog/fotes">
      <atom:title>Photos</atom:title>
      <accept>image/*</accept>
    </collection>
  </workspace>
</service>
END
    
    service = Atom::Service.new
    service.parse doc

    ws = service.workspaces.first
    assert_equal "My Blog", ws.title.to_s 

    coll = ws.collections.first
    assert_equal URI.parse("http://example.org/myblog/entries"), coll.uri
    assert_equal "Entries", coll.title.to_s
    assert_equal ["application/atom+xml;type=entry"], coll.accepts

    coll = ws.collections.last
    assert_equal URI.parse("http://example.org/myblog/fotes"), coll.uri
    assert_equal "Photos", coll.title.to_s
    assert_equal ["image/*"], coll.accepts

    http = service.instance_variable_get(:@http)
    assert_instance_of Atom::HTTP, http

    # collections should inherit the service's HTTP object
    assert_equal http, coll.instance_variable_get(:@http)

    # XXX write a test for relative hrefs
  end

  def test_write_introspection
    service = Atom::Service.new

    ws = service.workspaces.new

    ws.title = "Workspace 1"

    coll = Atom::Collection.new "http://example.org/entries"
    coll.title = "Entries"
    ws.collections << coll

    coll = Atom::Collection.new "http://example.org/audio"
    coll.title = "Audio"
    coll.accepts = ["audio/*"]
    ws.collections << coll

    nses = { "app" => Atom::PP_NS, "atom" => Atom::NS }

    doc = REXML::Document.new(service.to_s)

    assert_equal "http://www.w3.org/2007/app", doc.root.namespace

    ws = REXML::XPath.first( doc.root, 
                              "/app:service/app:workspace", 
                              nses )
   
    title = REXML::XPath.first( ws, "./atom:title", nses)

    assert_equal "Workspace 1", title.text
    assert_equal "http://www.w3.org/2005/Atom", title.namespace

    colls = REXML::XPath.match( ws, "./app:collection", nses)
    assert_equal(2, colls.length)

    entries = colls.first

    assert_equal "http://example.org/entries", entries.attributes["href"]

    title = REXML::XPath.first(entries, "./atom:title", nses)
    assert_equal "Entries", title.text

    accepts = REXML::XPath.first(entries, "./app:accept", nses)
    assert_nil accepts

    audio = colls.last

    assert_equal "http://example.org/audio", audio.attributes["href"]

    title = REXML::XPath.first(audio, "./atom:title", nses)
    assert_equal "Audio", title.text

    accepts = REXML::XPath.first(audio, "./app:accept", nses)
    assert_equal "audio/*", accepts.text
  end

  def test_dont_specify_http_object
    collection = Atom::Collection.new("http://necronomicorp.com/testatom?atom")

    assert_instance_of Atom::HTTP, collection.instance_variable_get("@http")
  end

  def test_collection_properly_inherits_feed
    collection = Atom::Collection.new("http://necronomicorp.com/testatom?atom")

    assert_equal [], collection.links
  end
end
