require 'socket'
require 'erb'
require 'openssl'
require 'hiera/backend/eyaml/options'
require 'hiera/backend/eyaml/subcommands/encrypt'

class RequestParser
  def parse(request)
    method, path, version = request.lines[0].split
    {
      path: path,
      method: method,
      headers: parse_headers(request),
      body: get_body(request)
    }
  end

  def parse_headers(request)
    headers = {}
    
    request.lines[1..-1].each do |line|
      return headers if line == "\r\n"
      
      header, value = line.split
      header        = normalize(header)
      headers[header] = value
    end
  end

  def get_body(request)
    hdrs = request
    hdrs =~ /Content-Length: (\d+)/
    body = $1 ? request.split("\r\n\r\n", 2).last : ''
    return body
  end

  def normalize(header)
    header.gsub(":", "").downcase.to_sym
  end
end

class ResponseBuilder
  def prepare(request)
    case request.fetch(:method).upcase
    when 'GET'
      if request.fetch(:path) == "/"
        send_ok_response(prepare_template(SERVER_ROOT + "/template/_index.html.erb").result(binding))
      else
        send_file_not_found
      end
    when 'POST'
      if request.fetch(:path) == "/encrypt"
        rawstring = request.fetch(:body).gsub("inputbar=", '')
        urldecoded = CGI.unescape(rawstring)
        pubkeyfile = SERVER_ROOT + "/pubkey/public_key.pkcs7.pem"
        eyamls = StringEncryption.new
        eyamls.load_public_key(pubkeyfile)
        encrypted = eyamls.encrypt_string(urldecoded, pubkeyfile)
        divclass = "m-fadeIn"
        send_ok_response(prepare_template(SERVER_ROOT + "/template/_index.html.erb").result(binding))
      else
        send_file_not_found
      end
    else
      not_implemented
    end
  end

  def prepare_template(templatepath)
    html = File.open(templatepath).read
    template = ERB.new(html)
    return template
  end

  def send_ok_response(data)
    Response.new(code: 200, data: data)
  end
  
  def send_file_not_found
    Response.new(code: 404)
  end

  def not_implemented
    Response.new(code: 501)
  end
end

class Response
  attr_reader :code
  
  def initialize(code:, data: "")
    @response =
    "HTTP/1.1 #{code}\r\n" +
    "Content-Length: #{data.size}\r\n" +
    "\r\n" +
    "#{data}\r\n"
    
    @code = code
  end
  
  def send(client)
    client.write(@response)
  end
end

class StringEncryption
  def load_public_key (public_key_file)
    raise "eyaml public key file not found / readable: #{public_key_file}" unless File.readable? public_key_file
    Hiera::Backend::Eyaml::Options['pkcs7_public_key'] = public_key_file
  end

  def encrypt_string (input, public_key='./pubkey/public_key.pkcs7.pem')
    load_public_key public_key
    Hiera::Backend::Eyaml::Options[:source] = 'string'
    Hiera::Backend::Eyaml::Options[:input_data] = input
    output = Hiera::Backend::Eyaml::Subcommands::Encrypt.execute
    output.chomp
  end
end
def custom_time(date)
  date.strftime("%FT%T.%L%z")
end
def main(conn, addr)
  Thread.new do
    client = addr 
    ts     =  custom_time(Time.now)
    puts "[#{ts}] #{client} connected"
    begin
      loop do
        request  = conn.readpartial(1024)
        request  = RequestParser.new.parse(request)
        response = ResponseBuilder.new.prepare(request)
        response.send(conn)
        ts     =  custom_time(Time.now)
        puts "[#{ts}] #{client} #{request.fetch(:method)} #{request.fetch(:path)} - #{response.code}"
      end
    rescue EOFError
      ts =  custom_time(Time.now)
      puts "[#{ts}] #{client} disconnected"
      conn.close
    end
  end
end

$stdout.sync     = true
proto     	     = (ARGV[0] || "https")
port             = (ARGV[1] || 8081).to_i
basepath         = File.expand_path(File.dirname(__FILE__))
SERVER_ROOT      = basepath + "/static"
Dir.chdir(basepath)
case proto
  when "https"	
    cntxt             = OpenSSL::SSL::SSLContext.new
    cntxt.cert        = OpenSSL::X509::Certificate.new(File.open(basepath + "/certs/cert.pem"))
    cntxt.key        = OpenSSL::PKey::RSA.new(File.open(basepath + "/certs/key.pem"))
    cntxt.ca_file     = basepath + "/certs/ca.pem"
    cntxt.min_version = OpenSSL::SSL::TLS1_2_VERSION
    tcp_srv           = TCPServer.new(port)
    ssl_server        = OpenSSL::SSL::SSLServer.new(tcp_srv, cntxt)
    loop do
      connx = ssl_server.accept
      main(connx, connx.peeraddr[3])
    end
  when "http"
    Socket.tcp_server_loop(port) do | connx, addr |
      main(connx, addr.ip_address)
    end
  else
    puts "#{proto} is not a valid protocol, use http or https"
    exit 1
end
