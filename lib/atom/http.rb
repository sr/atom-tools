require "net/http"
require 'uri'

module URI # :nodoc: all
  class Generic; def to_uri; self; end; end
end

class String # :nodoc:
  def to_uri; URI.parse(self); end
end

module Atom
  UA = "atom-tools 0.9.0"
  class Unauthorized < RuntimeError # :nodoc:
  end

  # An object which handles the details of HTTP - particularly
  # authentication and caching (neither of which are fully implemented).
  #
  # This object can be used on its own, or passed to an Atom::App,
  # Atom::Collection or Atom::Feed, where it will be used for requests.
  # 
  # All its HTTP methods return a Net::HTTPResponse
  class HTTP
    # used by the default #when_auth
    attr_accessor :user, :pass

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
    # authentication details
    #
    # it will be called with the base URL of the requested URL, and the realm used in the WWW-Authenticate header.
    # 
    # it should return a value of the form [username, password]
    def when_auth &block
      @get_auth_details = block
    end

    private
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
    
      raise Unauthorized unless user and pass
      
      if auth_type == "Basic"
        req.basic_auth user, pass
      else
        # TODO: implement Digest auth
        raise "atom-tools only supports Basic authentication"
      end
      
      res = Net::HTTP.start(url.host, url.port) { |h| h.request(req, body) }
      
      raise Unauthorized if res.kind_of? Net::HTTPUnauthorized
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
    
    def new_request(url_string, method, init_headers = {})
      headers = { "User-Agent" => UA }.merge(init_headers)
      
      url = url_string.to_uri
       
      rel = url.path
      rel += "?" + url.query if url.query

      [method.new(rel, headers), url]
    end
  end
end
