require "net/http"
require 'uri'

require "sha1"
require "md5"

module URI # :nodoc: all
  class Generic; def to_uri; self; end; end
end

class String # :nodoc:
  def to_uri; URI.parse(self); end
end

module Atom
  UA = "atom-tools 0.9.1"

  module DigestAuth
    CNONCE = Digest::MD5.new("%x" % (Time.now.to_i + rand(65535))).hexdigest

    @@nonce_count = -1

    # quoted-strings plus a few special cases for Digest
    def parse_wwwauth_digest param_string
      params = parse_quoted_wwwauth param_string
      qop = params[:qop] ? params[:qop].split(",") : nil

      param_string.gsub(/stale=([^,]*)/) do
        params[:stale] = ($1.downcase == "true")
      end

      params[:algorithm] = "MD5"
      param_string.gsub(/algorithm=([^,]*)/) { params[:algorithm] = $1 }

      params
    end

    def h(data); Digest::MD5.hexdigest(data); end
    def kd(secret, data); h(secret + ":" + data); end

    # HTTP Digest authentication (RFC 2617)
    def digest_authenticate(req, url, param_string = "")
      raise "Digest authentication requires a WWW-Authenticate header" if param_string.empty?

      params = parse_wwwauth_digest(param_string)
      qop = params[:qop]

      user, pass = username_and_password_for_realm(url, params[:realm])

      if params[:algorithm] == "MD5"
        a1 = user + ":" + params[:realm] + ":" + pass
      else
        # XXX MD5-sess
        raise "I only support MD5 digest authentication (not #{params[:algorithm].inspect})"
      end

      if qop.nil? or qop.member? "auth"
        a2 = req.method + ":" + req.path
      else
        # XXX auth-int
        raise "only 'auth' qop supported (none of: #{qop.inspect})"
      end

      if qop.nil?
        response = kd(h(a1), params[:nonce] + ":" + h(a2))
      else
        @@nonce_count += 1
        nc = ('%08x' % @@nonce_count) 
   
        # XXX auth-int
        data = "#{params[:nonce]}:#{nc}:#{CNONCE}:#{"auth"}:#{h(a2)}"

        response = kd(h(a1), data)
      end

      header = %Q<Digest username="#{user}", uri="#{req.path}", realm="#{params[:realm]}", response="#{response}", nonce="#{params[:nonce]}">
   
      if params[:opaque]
        header += %Q<, opaque="#{params[:opaque]}">
      end

      if params[:algorithm] != "MD5"
        header += ", algorithm=#{algo}"
      end

      if qop
        # XXX auth-int
        header += %Q<, nc=#{nc}, cnonce="#{CNONCE}", qop=auth>
      end

      req["Authorization"] = header
    end
  end

  class HTTPException < RuntimeError # :nodoc:
  end
  class Unauthorized < Atom::HTTPException  # :nodoc:
  end
  class WrongMimetype < Atom::HTTPException # :nodoc:
  end

  # An object which handles the details of HTTP - particularly
  # authentication and caching (neither of which are fully implemented).
  #
  # This object can be used on its own, or passed to an Atom::Service,
  # Atom::Collection or Atom::Feed, where it will be used for requests.
  # 
  # All its HTTP methods return a Net::HTTPResponse
  class HTTP
    include DigestAuth

    # used by the default #when_auth
    attr_accessor :user, :pass

    # XXX doc me
    # :basic, :wsse, nil
    attr_accessor :always_auth

    def initialize # :nodoc:
      @get_auth_details = lambda do |abs_url, realm|
        if @user and @pass
          [@user, @pass]
        else
          nil
        end
      end
    end

    # GETs an url
    def get url, headers = {}
      http_request(url, Net::HTTP::Get, nil, headers)
    end
  
    # POSTs body to an url
    def post url, body, headers = {}
      http_request(url, Net::HTTP::Post, body, headers)
    end

    # PUTs body to an url
    def put url, body, headers = {}
      http_request(url, Net::HTTP::Put, body, headers)
    end

    # DELETEs to url
    def delete url, body = nil, headers = {}
      http_request(url, Net::HTTP::Delete, body, headers)
    end

    # a block that will be called when a remote server responds with
    # 401 Unauthorized, so that your application can prompt for
    # authentication details.
    #
    # the default is to use the values of @user and @pass.
    #
    # your block will be called with two parameters
    # abs_url:: the base URL of the request URL
    # realm:: the realm used in the WWW-Authenticate header 
    # (will be nil if there is no WWW-Authenticate header)
    # 
    # it should return a value of the form [username, password]
    def when_auth &block # :yields: abs_url, realm
      @get_auth_details = block
    end

    private
    # parses plain quoted-strings
    def parse_quoted_wwwauth param_string
      params = {}

      param_string.gsub(/(\w+)="(.*?)"/) { params[$1.to_sym] = $2 }

      params
    end

    # HTTP Basic authentication (RFC 2617)
    def basic_authenticate(req, url, param_string = "")
      params = parse_quoted_wwwauth(param_string)

      user, pass = username_and_password_for_realm(url, params[:realm])

      req.basic_auth user, pass
    end

    # WSSE authentication <http://www.xml.com/pub/a/2003/12/17/dive.html>
    def wsse_authenticate(req, url, params = {})
      # from <http://www.koders.com/ruby/fidFB0C7F9A0F36CB0F30B2280BDDC4F43FF1FA4589.aspx?s=ruby+cgi>.
      # (thanks midore!)
      user, pass = username_and_password_for_realm(url, params["realm"])

      nonce = Array.new(10){ rand(0x100000000) }.pack('I*')
      nonce_base64 = [nonce].pack("m").chomp
      now = Time.now.utc.iso8601
      digest = [Digest::SHA1.digest(nonce + now + pass)].pack("m").chomp
      credentials = sprintf(%Q<UsernameToken Username="%s", PasswordDigest="%s", Nonce="%s", Created="%s">,
                            user, digest, nonce_base64, now)
      req['X-WSSE'] = credentials
      req["Authorization"] = 'WSSE profile="UsernameToken"'
    end

    def username_and_password_for_realm(url, realm)
      abs_url = (url + "/").to_s
      user, pass = @get_auth_details.call(abs_url, realm)

      unless user and pass
        raise Unauthorized, "You must provide a username and password"
      end

      [ user, pass ]
    end

    # performs a generic HTTP request.
    def http_request(url_s, method, body = nil, init_headers = {}, www_authenticate = nil)
      req, url = new_request(url_s, method, init_headers)
   
      # two reasons to authenticate;
      if @always_auth
        self.send("#{@always_auth}_authenticate", req, url)
      elsif www_authenticate
        # XXX multiple challenges, multiple headers
        param_string = www_authenticate.sub!(/^(\w+) /, "")
        auth_type = $~[1]
        self.send("#{auth_type.downcase}_authenticate", req, url, param_string)
      end
 
      res = Net::HTTP.start(url.host, url.port) { |h| h.request(req, body) }

      if res.kind_of? Net::HTTPUnauthorized
        if @always_auth or www_authenticate # XXX and not stale (Digest only) 
          # we've tried the credentials you gave us once and failed
          raise Unauthorized, "Your username and password were rejected"
        else
          # once more, with authentication
          res = http_request(url_s, method, body, init_headers, res["WWW-Authenticate"])

          if res.kind_of? Net::HTTPUnauthorized
            raise Unauthorized, "Your username and password were rejected"
          end
        end
      end

      # a bit of added convenience
      res.extend Atom::HTTPResponse

      res
    end
    
    def new_request(url_string, method, init_headers = {})
      headers = { "User-Agent" => UA }.merge(init_headers)
      
      url = url_string.to_uri
       
      rel = url.path
      rel += "?" + url.query if url.query

      [method.new(rel, headers), url]
    end
  end

  module HTTPResponse
    # this should probably support ranges (eg. text/*)
    def validate_content_type( valid )
      raise Atom::HTTPException, "HTTP response contains no Content-Type!" unless self.content_type

      media_type = self.content_type.split(";").first

      unless valid.member? media_type.downcase
        raise Atom::WrongMimetype, "unexpected response Content-Type: #{media_type.inspect}. should be one of: #{valid.inspect}"
      end
    end
  end
end
