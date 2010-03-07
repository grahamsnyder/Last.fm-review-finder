require 'rss'
require 'time'

class ReviewSource
  
  attr_reader :reviews, :name
  
  def initialize(name, rss_uri)
    @name, @rss_uri = name, rss_uri
    @review_stream = nil
    @reviews = {}
    @last_parsed = @last_fetched = nil
  end

  def fetch_reviews
    rss_content = ''
    open(@rss_uri) do |f|
      rss_content = f.read
    end
    @review_stream = RSS::Parser.parse(rss_content, false)
    @last_fetched = Time.now
    puts "Fetched at #{@last_fetched}" if Debug
    self
  end

  def parse
    return self if @last_parsed and @last_fetched and @last_parsed > @last_fetched
    @review_stream.items.each do |item|
      artist, release = parse_title(item)
      norm_name = artist.normalize_band_name
      review = Review.new(artist, release, item.link, item.date)
      (@reviews[norm_name] ||= [])
      @reviews[norm_name] << review unless @reviews[norm_name].include? review
    end
    @last_parsed = Time.now
    self
  end
  
  def fetch_and_parse
    fetch_reviews
    parse
    self
  end

  def ==(other)
    @rss_uri = other.rss_uri
  end
  
  def to_s
    string = "Reviews from #{@name}:\n"
    if @reviews.empty?
      string + "none"
    else
      @reviews.values.inject(string) do |string, artist|
        artist.each {|review| string += ("#{review.to_s}\n")}
        string
      end
    end
  end
end

class Pitchfork_RSS < ReviewSource
  def parse_title(item)
      item.title.strip.gsub(/\s+/, ' ').split(/ - /)
  end
end

class Metacritic_Music < ReviewSource
  def parse_title(item)
    r, a = item.title.strip.gsub(/\s+/, ' ').split(/ by /)
    [a, r]
  end
end


class Review
  attr_reader :artist, :release, :link, :date
  
  def initialize(artist, release, link, date=nil)
    @artist = artist
    @release = release
    @link = link
    @date = date
  end
  
  def to_s
    "#{@artist}: #{@release}, #{@link}"
  end
  
  def ==(other)
    @link = other.link
  end
  
end