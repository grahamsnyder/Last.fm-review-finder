# encoding: utf-8
require 'test/unit'
require 'lastfm'

class TestArtist < Test::Unit::TestCase
  
  def setup
    @api = LastFmApi.new('api_key')
    @artist_punc = @api.get_artist('¡Forward, Russia! !&$\'£()¡;  ')
    @artist_norm = @api.get_artist('forward russia')
    @artist_diff = @api.get_artist('graham snyder rules')
  end
  
  def test_uniqueness
    assert_raise(RuntimeError) { Artist.new(@api, 'asdf') }
    assert_same(@artist_punc, @artist_norm, "artist_punc: #{@artist_punc.name.normalize_band_name}\nartist_norm: #{@artist_norm.name.normalize_band_name}")
  end
  
  def test_equal
    puts "***" + @artist_punc.name.normalize_band_name + "***"
    assert_equal(@artist_punc.hash, @artist_norm.hash)
    assert(@artist_punc.eql?(@artist_norm))
    assert_not_same(@artist_punc, @artist_diff)
  end
  
  def test_uniq
    assert_equal([@artist_punc, @artist_norm, @artist_diff, @artist_norm].uniq, [@artist_norm, @artist_diff])
  end
  
  def test_comparable
    assert(@artist_diff > @artist_norm)
  end

  
end

class TestUser
  def setup
  end
end