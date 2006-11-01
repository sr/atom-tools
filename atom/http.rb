require "net/http"
require 'uri'

# this authorization code is yet to be put to use
# Written by Eric Hodel <drbrain@segment7.net>

require 'digest/md5'

module DigestAuth
  @@nonce_count = -1

  CNONCE = Digest::MD5.new("%x" % (Time.now.to_i + rand(65535))).hexdigest

  def self.gen_auth_header(uri, params, user, password, is_IIS = false)
    @@nonce_count += 1

    a_1 = "#{user}:#{params['realm']}:#{password}"
    a_2 = "GET:#{uri.path}"
    request_digest = ''
    request_digest << Digest::MD5.new(a_1).hexdigest
    request_digest << ':' << params['nonce']
    request_digest << ':' << ('%08x' % @@nonce_count)
    request_digest << ':' << CNONCE
    request_digest << ':' << params['qop']
    request_digest << ':' << Digest::MD5.new(a_2).hexdigest

    header = ''
    header << "Digest username=\"#{user}\", "
    header << "realm=\"#{params['realm']}\", "
    if is_IIS then
      header << "qop=\"#{params['qop']}\", "
    else
      header << "qop=#{params['qop']}, "
    end
    header << "uri=\"#{uri.path}\", "
    header << "nonce=\"#{params['nonce']}\", "
    header << "nc=#{'%08x' % @@nonce_count}, "
    header << "cnonce=\"#{CNONCE}\", "
    header << "response=\"#{Digest::MD5.new(request_digest).hexdigest}\""

    return header
  end
end

class URI::Generic
  def to_uri
    self
  end
end

class String
  def to_uri
    URI.parse(self)
  end
end

module Atom
  UA = "atom-tools 0.9.0"
  class Unauthorised < RuntimeError; end

  class HTTP
    attr_accessor :user, :pass

    def initialize
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
  
    # POSTs body at an url
    def post url, body, headers = {}
      http_request(url, Net::HTTP::Post, body, headers)
    end

    # PUTs body at an url
    def put url, body, headers = {}
      http_request(url, Net::HTTP::Put, body, headers)
    end

    # DELETEs an url
    def delete url, body = nil, headers = {}
      http_request(url, Net::HTTP::Delete, body, headers)
    end

    def when_auth &block
      @get_auth_details = block
    end

    def parse_wwwauth www_authenticate
      auth_type = www_authenticate.split[0] # "Digest" or "Basic"
      auth_params = {}
      
      www_authenticate =~ /^(\w+) (.*)/

      $2.gsub(/(\w+)="(.*?)"/) { auth_params[$1] = $2 }

      [ auth_type, auth_params ]
    end

    # performs an authenticated http request
    def authenticated_request(url_string, method, wwwauth, body = nil, init_headers = {})

      auth_type, params = parse_wwwauth(wwwauth)
      req, url = new_request(url_string, method, init_headers)
      
      realm = params["realm"]
      abs_url = (url + "/").to_s

      user, pass = @get_auth_details.call(abs_url, realm)
    
      raise Unauthorised unless user and pass
      
      if auth_type == "Basic"
        req.basic_auth user, pass
      else
        # TODO: implement Digest auth
        raise "atom-tools only supports Basic authentication"
      end
      
      res = Net::HTTP.start(url.host, url.port) { |h| h.request(req, body) }
      
      raise Unauthorised if res.kind_of? Net::HTTPUnauthorized
      res
    end

    # performs a regular http request. if it responds 401 
    # then it retries using @user and @pass for authentication
    def http_request(url_string, method, body = nil, init_headers = {})
      req, url = new_request(url_string, method, init_headers)
      
      res = Net::HTTP.start(url.host, url.port) { |h| h.request(req, body) }

      if res.kind_of? Net::HTTPUnauthorized
        res = authenticated_request(url, method, res["WWW-Authenticate"], body, init_headers)
      end

      res
    end
    
    private
    def new_request(url_string, method, init_headers = {})
      headers = { "User-Agent" => UA }.merge(init_headers)
      
      url = url_string.to_uri
       
      rel = url.path
      rel += "?" + url.query if url.query

      [method.new(rel, headers), url]
    end
  end
end
