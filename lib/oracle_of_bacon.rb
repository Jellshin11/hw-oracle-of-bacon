require 'byebug'                # optional, may be helpful
require 'open-uri'              # allows open('http://...') to return body
require 'cgi'                   # for escaping URIs
require 'nokogiri'              # XML parser
require 'active_model'          # for validations

class OracleOfBacon

  class InvalidError < RuntimeError ; end
  class NetworkError < RuntimeError ; end
  class InvalidKeyError < RuntimeError ; end

  attr_accessor :from, :to
  attr_reader :api_key, :response, :uri
  
  include ActiveModel::Validations
  validates_presence_of :from
  validates_presence_of :to
  validates_presence_of :api_key
  validate :from_does_not_equal_to

  DEFAULT_CONNECTION = 'Kevin Bacon'
  NETWORK_ERRORS = [
    Timeout::Error,
    Errno::EINVAL,
    Errno::ECONNRESET,
    EOFError,
    Net::HTTPHeaderSyntaxError,
    Net::HTTPBadResponse,
    Net::ProtocolError
  ]

  def from_does_not_equal_to
    errors.add(:to,'from no puede ser igual a to') if from == to 
  end

  def initialize(api_key='38b99ce9ec87')
    @api_key = api_key
    @from = DEFAULT_CONNECTION
    @to= DEFAULT_CONNECTION
    @uri=nil
    @response= nil
  end

  def find_connections
    make_uri_from_arguments
    begin
      xml = URI.parse(uri).read
    rescue *NETWORK_ERRORS => e
       raise NetworkError, e.message
    end
    @response = Response.new(xml)
  end

  def make_uri_from_arguments
    @uri="http://oracleofbaconorg/cgi-bin/xml?p=#{scaped_api_key}&a=#{scaped_from}&b=#{scaped_to}"
  end
      
  class Response
    attr_reader :type, :data
    # create a Response object from a string of XML markup.
    def initialize(xml)
      @doc = Nokogiri::XML(xml)
      parse_response
    end

    private

    def parse_response
      if ! @doc.xpath('/error').empty?
        parse_error_response
      elsif !@doc.xpath('/link').empty?
        parse_graph_response
      elsif !@doc.xpath('/spellcheck').empty?
        parse_spellcheck_response
      else
        parse_unknown_response
      end
    end

    def parse_error_response
      @type = :error
      @data = 'Unauthorized access'
    end

    def parse_graph_response
      @type = :graph
      @data = actors.zip(movies).flatten.compact.map(&:text)
    end

    def parse_spellcheck_response
      @type = :spellcheck
      @data = @doc.xpath('//match').map(&:text)
    end

    def parse_unknown_response
      @type = :unknown
      @data = 'Unknown response'
    end

    def actors
      @doc.xpath('//actor')
    end

    def movies
      @doc.xpath('//movie')
    end
  end

  private

  
  %w[api_key from to].each do |param|
    define_method "scaped_#{param}" do
      CGI.escape send(param)
    end
  end
end

