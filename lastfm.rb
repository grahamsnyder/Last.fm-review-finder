# encoding: UTF-8
require 'rubygems'
require 'net/http'
require 'open-uri'
require 'hpricot'
require 'cgi'
require 'time'

Debug = false unless defined? Debug

class String
  #Add band name normalization to String class, for comparisons etc
  #TODO: this might be broken - possible false equal for different artists, doesn't include accents, etc
  def normalize_band_name
    if Debug
      nname = force_encoding('UTF-8').downcase.gsub(/[+&]/,' and ').gsub(/([[:punct:]]|¡|£)/, '').gsub(/\s+/, ' ').strip
      puts self
      puts encoding.name
      puts nname.encoding
      puts nname
    end
    force_encoding('UTF-8').downcase.gsub(/[+&]/,' and ').gsub(/([[:punct:]]|¡|£)/, '').gsub(/\s+/, ' ').strip
  end
  
  def normalize_band_name!
    self.replace(normalize_band_name)
  end
end

class LastFmApi
  API_ROOT = "ws.audioscrobbler.com"
  API_VERSION = '2.0'
  
  attr_accessor :artists, :users
  
  def initialize(api_key)
    @api_key = api_key
    @artists = {}
    @users   = {}
  end

  def call(method, params)
    api_call = "http://#{API_ROOT}/#{API_VERSION}/?method=#{method}"
    
    params['api_key'] = @api_key
    params.each do |par, value|
      api_call << "&#{CGI::escape(par)}=#{CGI::escape(value)}"
    end
    
    if Debug
      puts "calling #{method} with params:"
      params.each {|k,v| puts "    #{k} = #{v}"}
      puts "#{api_call}\n\n"
    end

    Hpricot::XML(open(api_call))
    
    #add exception shit for SocketError, Bad request, etc
  end
  
  def get_user(username)
    unless @users[username.normalize_band_name]
      @users[username.normalize_band_name] = nil
      @users[username.normalize_band_name] = User.new(self, username)
    end
    @users[username.normalize_band_name]
  end
  
  def get_artist(artist)
    #When get_info is called on an artist, last.fm returns the correct url 
    #if the correct spelling is used. If the spelling is wrong, the url has
    #+noredirect in and the first similar artist is the correct spelling.
    doc = Artist.new(self, artist).get_info
    names = (doc/'name').collect {|name| name.inner_text}
    urls =  (doc/'url').collect {|url| url.inner_text}
    urls[0].match(/\/\+noredirect/) ? name = a[1] : name = a[0]
    
    unless @artists[artist.normalize_band_name]
      @artists[artist.normalize_band_name] = nil
      @artists[artist.normalize_band_name] = Artist.new(self, artist)
    end
    @artists[artist.normalize_band_name]
  end
end

class User
 attr_reader :username, :top_artists, :norm_name
 protected :norm_name
  
  def initialize(api, username)
    raise ArgumentError if username.empty?
    @api = api
    @username = username
    @norm_name = username.normalize_band_name
    puts @api.class
    if !@api.users.key? @norm_name or @api.users[@norm_name]
      raise ("Warning: Using User#new directly does not ensure unique users." +
             " Use Lastfm_api#get_user instead.")
    end
    @top_artists = []
    @artists_updated = nil
  end

  private
  def call(method, params)
    params['user'] = @username.downcase
    @api.call("user.#{method}", params)
  end

  public
  def get_artists(period = nil, force = false)
    return @top_artists if @artists_updated and Time.now - @artists_updated < 24*3600 unless force
    
    params = {}
    if period 
      raise ArgumentError unless ['7day', '3month', '6month', '12month', 'overall'].include? period
      params['period'] = period
    end
    doc = call('gettopartists', params)
    @top_artists = (doc/'name').collect {|name| @api.get_artist(name.inner_text)}
    @artists_updated = Time.now
    @top_artists
  end
end

class Artist
  
  include Comparable
  
  attr_reader :name, :similar, :norm_name
  protected :norm_name
  
  def initialize(api, name)
    raise ArgumentError if name.empty?
    @api = api
    @name = name
    @norm_name = name.normalize_band_name
    if !@api.artists.key? @norm_name or @api.artists[@norm_name]
      raise ("Warning: Using Artist#new directly does not ensure unique artists." +
             " Use Lastfm_api#get_artist instead.")
    end
    @similar = []
  end

  private
  def call(method, params)
    params['artist'] = @name.downcase
    @api.call("artist.#{method}", params)
  end
  
  public
  def get_similar(limit = nil)
    params = {}
    if limit
      raise ArgumentError unless limit.is_a? Numeric
      params['limit'] = limit.to_s
    end
    doc = call('getsimilar', params)
    @similar = (doc/'name').collect {|name| @api.get_artist(name.inner_text)}
  end
  
  def get_info(username=nil)
    params = {}
    params['username'] = username if username
    doc = call('getinfo', params)
    doc
  end

  def to_s
    @name
  end
  
  def hash
    @norm_name.hash
  end
  
  def eql?(other)
    return false unless other.class == Artist
    self==other
  end
  
  def ==(other)
    @norm_name == other.norm_name
  end

  def <=>(other)
    @norm_name <=> other.norm_name
  end
  
end