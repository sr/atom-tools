require "atom/http"
require "webrick"

class AtomProtocolTest < Test::Unit::TestCase
  def setup
    @http = Atom::HTTP.new
    @port = rand(1024) + 1024
    @s = WEBrick::HTTPServer.new :Port => @port, 
               :Logger => WEBrick::Log.new($stderr, WEBrick::Log::FATAL), 
               :AccessLog => []
  end

  def test_parse_wwwauth
    header = 'Basic realm="SokEvo"'
    
    auth_type, auth_params = @http.parse_wwwauth header

    assert_equal "Basic", auth_type
    assert_equal "SokEvo", auth_params["realm"]
  end

  def test_GET
    @s.mount_proc("/") do |req,res|
      assert_equal("/", req.path)

      res.content_type = "text/plain"
      res.body = "just junk"

      @s.stop
    end

    one_shot

    res = get_root
    
    assert_equal("200", res.code)
    assert_equal("text/plain", res.content_type)
    assert_equal("just junk", res.body)
  end

  def test_GET_headers
    @s.mount_proc("/") do |req,res|
      assert_equal("tester agent", req["User-Agent"])
      
      @s.stop
    end

    one_shot

    res = get_root("User-Agent" => "tester agent")

    assert_equal("200", res.code)
  end

  def test_basic_auth
    @s.mount_proc("/") do |req,res|
      WEBrick::HTTPAuth.basic_auth(req, res, "test authentication") do |u,p|
        u == "test" and p == "pass"
      end

      res.body = "sooper-secret!"
      @s.stop
    end

    one_shot
    
    assert_raises(Atom::Unauthorised) { get_root }

    @http.when_auth do |abs_url,realm|
      assert_equal "http://localhost:#{@port}/", abs_url 
      assert_equal "test authentication", realm

      ["test", "pass"]
    end
    
    one_shot
  
    res = get_root
    assert_equal("200", res.code)
    assert_equal("sooper-secret!", res.body)
  end

  def get_root(*args); @http.get("http://localhost:#{@port}/", *args); end
  def one_shot; Thread.new { @s.start }; end
end
