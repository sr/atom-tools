require "test/unit"

require "atom/app"

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

    service = <<END
<service xmlns="http://purl.org/atom/app#"
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
    
    http = FakeHTTP.new({ "http://example.com/service.xml" => service }, "application/atomserv+xml")


    server = Atom::App.new "http://example.com/service.xml", http

    coll = server.collections.first
    assert_equal(URI.parse("http://example.org/myblog/entries"), coll.uri)
    assert_equal("Entries", coll.title.to_s)
    assert_equal("entry", coll.accepts)

    coll = server.collections.last
    assert_equal(URI.parse("http://example.org/myblog/fotes"), coll.uri)
    assert_equal("Photos", coll.title.to_s)
    assert_equal("image/*", coll.accepts)

    # XXX write a test for relative hrefs
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
