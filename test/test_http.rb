require "test/unit"

require "atom/http"
require "webrick"
require "sha1"

class AtomProtocolTest < Test::Unit::TestCase
  REALM = "test authentication"
  USER = "test_user"
  PASS = "aoeuaoeu"
  SECRET_DATA = "I kissed a boy once"

  def setup
    @http = Atom::HTTP.new
    @port = rand(1024) + 1024
    @s = WEBrick::HTTPServer.new :Port => @port, 
               :Logger => WEBrick::Log.new($stderr, WEBrick::Log::FATAL), 
               :AccessLog => []
  end

  def test_parse_wwwauth
    header = 'realm="SokEvo"'
   
    params = @http.send :parse_quoted_wwwauth, header
    assert_equal "SokEvo", params[:realm]

    header = 'opaque="07UrfUiCYac5BbWJ", algorithm=MD5-sess, qop="auth", stale=TRUE, nonce="MDAx0Mzk", realm="test authentication"'

    params = @http.send :parse_wwwauth_digest, header

    assert_equal "test authentication", params[:realm]
    assert_equal "MDAx0Mzk", params[:nonce]
    assert_equal true, params[:stale]
    assert_equal "auth", params[:qop]
    assert_equal "MD5-sess", params[:algorithm]
    assert_equal "07UrfUiCYac5BbWJ", params[:opaque]
  end

  def test_GET
    @s.mount_proc("/") do |req,res|
      assert_equal("/", req.path)

      res.content_type = "text/plain"
      res.body = "just junk"

      @s.stop
    end

    one_shot

    get_root
    
    assert_equal("200", @res.code)
    assert_equal("text/plain", @res.content_type)
    assert_equal("just junk", @res.body)
  end

  def test_GET_headers
    @s.mount_proc("/") do |req,res|
      assert_equal("tester agent", req["User-Agent"])
      
      @s.stop
    end

    one_shot

    get_root("User-Agent" => "tester agent")

    assert_equal("200", @res.code)
  end

  def test_basic_auth
    @s.mount_proc("/") do |req,res|
      WEBrick::HTTPAuth.basic_auth(req, res, REALM) do |u,p|
        u == USER and p == PASS
      end

      res.body = SECRET_DATA
      @s.stop
    end

    one_shot
   
    # with no credentials
    assert_raises(Atom::Unauthorized) { get_root }

    @http.user = USER
    @http.pass = "incorrect_password"

    # with incorrect credentials
    assert_raises(Atom::Unauthorized) { get_root }

    @http.when_auth do |abs_url,realm|
      assert_equal "http://localhost:#{@port}/", abs_url 
      assert_equal REALM, realm

      [USER, PASS]
    end
    
    one_shot
  
    get_root
    assert_equal "200", @res.code 
    assert_equal SECRET_DATA, @res.body 
  end

  def test_digest_auth
    # a dummy userdb 
    userdb = {}
    userdb[USER] = PASS

    def userdb.get_passwd(realm, user, reload)
      assert_equal REALM, realm
      assert_equal USER, user
      Digest::MD5::hexdigest([user, realm, self["user"]].join(":"))
    end
      
    authenticator = WEBrick::HTTPAuth::DigestAuth.new(
      :UserDB => userdb,
      :Realm => REALM
    )

    @s.mount_proc("/") do |req,res|
      authenticator.authenticate(req, res)
      res.body = SECRET_DATA
    end
   
    one_shot

    # no credentials
    assert_raises(Atom::Unauthorized) { get_root }
    
    @http.user = USER
    @http.pass = PASS

    # correct credentials
    res = get_root
    assert_equal SECRET_DATA, res.body

    @s.stop
  end

  def test_wsse_auth
    @s.mount_proc("/") do |req,res|
      assert_equal 'WSSE profile="UsernameToken"', req["Authorization"]

      xwsse = req["X-WSSE"]

      p = @http.send :parse_quoted_wwwauth, xwsse

      assert_equal USER, p[:Username]
      assert_match /^UsernameToken /, xwsse

      # un-base64 in preparation for SHA1-ing
      nonce = p[:Nonce].unpack("m").first

      # Base64( SHA1( Nonce + CreationTimestamp + Password ) )
      pd_string = nonce + p[:Created] + PASS
      password_digest = [Digest::SHA1.digest(pd_string)].pack("m").chomp

      assert_equal password_digest, p[:PasswordDigest]

      res.body = SECRET_DATA
      @s.stop
    end

    one_shot

    @http.always_auth = :wsse
    @http.user = USER
    @http.pass = PASS
    
    get_root

    assert_equal "200", @res.code 
    assert_equal SECRET_DATA, @res.body
  end

  def get_root(*args)
    @res = @http.get("http://localhost:#{@port}/", *args)
  end

  def one_shot; Thread.new { @s.start }; end
end
