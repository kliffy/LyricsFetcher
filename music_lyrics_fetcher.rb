#user httpparty to make requests and fetch lyrics
require 'byebug'
require 'httparty'
require 'id3lib'
require 'nokogiri'

#ruby music_lyrics_fetcher.rb -l /Volumes/STORAGE/Music/Metal/Evergrey/2014\ -\ Hymns\ For\ The\ Broken/

def get_shit_for_song(folder_location, file, giri, songs_lyrics, track_increment = 0)
  if !file.downcase.include?('.mp3')
    puts "### Skipping #{file}. Not mp3"
    return
  end

  file_location = if folder_location[folder_location.length - 1] == '/'
    folder_location + file
  else
    folder_location + '/' + file
  end

  tag = ID3Lib::Tag.new(file_location)

  song_lyrics = []

  track = tag.track
  unless track
    puts "### Skipping #{file}. No track"

    # matched_track = file.match(/(\d*)/)[1]
    # if matched_track
    #   tag.track = matched_track.to_i
    #   tag.update!
    #   track = matched_track.to_i + track_increment
    # end

    # puts "### Giving #{file} track #{matched_track.to_i + track_increment}"

    return
  end
  if track.include?("\x00")
    unpacked = track.unpack("C*")
    if (unpacked[0] == 254 || unpacked[0] == 255) && (unpacked[1] == 254 || unpacked[1] == 255)
      track = track[2..track.length]
    end

    track = track.gsub("\x00","")
  end

  # if track.to_i.to_s == '0'
  #   #then its not parsing the track correctly. check name if it has a number
  #   track = file.match(/(\d*)\.*/)[1]
  # end

  track = (track.to_i + track_increment).to_s

  named_element = giri.search(".lyrics a[name='#{track}']").first

  if named_element
    h3_start_element = named_element.parent

    current_element = h3_start_element.next_sibling

    while current_element.name == 'br' || current_element.name == 'text' || current_element.name == 'i'
      song_lyrics << current_element.text.gsub(/\n/, '') if current_element.name == 'text' || current_element.name == 'i'
      current_element = current_element.next_sibling
    end

    songs_lyrics[track] = {location: file_location, lyrics: song_lyrics.join("\n")}
  else
    puts "### Skipping Song #{file_location}. No lyrics found"
  end
end

while ARGV.count != 0
  case ARGV.shift
  when '-l'
    folder_location = ARGV.shift
  when '-url'
    api_endpoint = ARGV.shift
  when '-v'

  end
end

artist, album_name = [folder_location.match(/\/([^\/]*)\/([^\/]*)\/?$/)].map{|v| [v[1].downcase.gsub(" ", ''),v[2].downcase.gsub(" ", '').gsub(/[\W\d]/,'')]}.flatten
api_endpoint = "http://www.darklyrics.com/lyrics/#{artist}/#{album_name}.html" unless api_endpoint

puts "Fetching from #{api_endpoint}\n"
#http://www.darklyrics.com/lyrics/amorphis/undertheredcloud.html#2
response = HTTParty.get(api_endpoint)

giri = Nokogiri::HTML.fragment(response.body)

songs_lyrics = {}

track_increment = 0
Dir.entries(folder_location).select {|f| !File.directory? f}.sort_by{|v| v.downcase}.each do |file|

  if file.downcase.include?('cd') && File.directory?(folder_location + file)

    inner_increment = 0
    Dir.entries(folder_location + file).select {|f| !File.directory? f}.sort_by{|v| v.downcase}.each do |inner_file|

      lyrics = get_shit_for_song(folder_location + file, inner_file, giri, songs_lyrics, track_increment)

      inner_increment += 1 if lyrics
    end

    track_increment += inner_increment
  else
    lyrics = get_shit_for_song(folder_location, file, giri, songs_lyrics)
  end
end

songs_lyrics.keys.sort{|a,b| a.to_i <=> b.to_i}.each do |k|
  puts songs_lyrics[k][:location] + "\n\n"
  puts songs_lyrics[k][:lyrics]
end

print "\n\nYou cool with this? (y/n)\n"
input = gets.strip

if input == 'y'
  songs_lyrics.each do |k,v|
    tag = ID3Lib::Tag.new(v[:location])
    tag.lyrics = v[:lyrics]
    tag.update!
  end
  puts "Saved!"
else
  puts "Not Saving =("
end
