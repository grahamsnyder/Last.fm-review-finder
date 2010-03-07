#encoding: utf-8
Debug = false
require 'TestLastFm' if Debug

require 'lastfm'
require 'readline'
require 'ReviewSources'


include Readline
#put tab completion shit here

GS_API_KEY = '0d01292c6827570c72a647903cc94e8b'
PF_LATEST = "http://feeds2.feedburner.com/PitchforkAlbumReviews"
PF_BEST_NEW = "http://feeds2.feedburner.com/PitchforkBestNewAlbums"
METACRITIC = "http://www.metacritic.com/rss/music/album.xml"

api = LastFmApi.new(GS_API_KEY)

#puts ARGV

username = readline("Enter username: ", true) unless Debug
username = 'grahamsnyder' if Debug
user = api.get_user(username)

myartists = user.get_artists('3month')

artistslist = myartists.inject(myartists) do |list, artist|
  list += artist.get_similar(20)
end
artistslist.uniq!

lfm_norm_names = artistslist.collect {|artist| artist.name.normalize_band_name}

sources = []
sources << Pitchfork_RSS.new("Pitchfork Best New Music", PF_BEST_NEW)
sources << Pitchfork_RSS.new("Pitchfork Latest Reviews", PF_LATEST)
sources << Metacritic_Music.new("Metacritic Music", METACRITIC)

sources.each do |feed|
  feed.fetch_and_parse
  selected_reviews = feed.reviews.keys & lfm_norm_names
  puts "\nReviews from #{feed.name}:"
  puts "none" if selected_reviews.empty?
  selected_reviews.each do |artist|
    feed.reviews[artist].each {|review| puts review}
  end
end