#!/usr/bin/env ruby

require 'mysql2'
require 'rspotify'

def options
  { host: ENV['SQUIRREL_WIN7_HOST'],
    username: ENV['SQUIRREL_WIN7_USER'],
    password: ENV['SQUIRREL_WIN7_PWD'],
    database: ENV['SQUIRREL_WIN7_DB'] }
end

def client
  @client ||= Mysql2::Client.new(options)
end

def authenticate!
  RSpotify.authenticate(ENV['SPOTIFY_ID'], ENV['SPOTIFY_SECRET'])
end

def already_checked?(artist, title)
  return unless File.exist?(filename)
  File.foreach(filename).grep(Regexp.new("#{artist} - #{title}")).any?
end

def update_song(id, artist, title)
  return if already_checked?(artist, title)
  @id = id
  @artist = artist
  @title = title
  @earliest_year = 3000
  update_year(artist, title)
end

def songlist(list = [])
  sql = 'SELECT ID, title, artist FROM songlist ' \
        "WHERE songtype = \'S\' AND (albumyear = \'\' " \
        "OR albumyear = \'1900\' OR albumyear = \'1700\')"
  results = client.query(sql)
  results.each { |s| list << [s['ID'], s['artist'].to_s, s['title']] }
  list
end

def show_options(results)
  index = 0
  results.each do |artist, title, album, year|
    index += 1
    @earliest_year = year.to_i if @earliest_year > year.to_i
    puts "#{index}) [#{year}] #{artist} - #{title} [#{album}]"
  end

  print "\n#{artist} - #{title} [#{earliest_year}] " \
        'or n) (q=quit) => '
end

def year_chooser(results)
  show_options(results)
  response = gets.chomp
  abort("Bye!\n\n") if response == 'q'
  response = response.to_i - 1
  return @earliest_year if response == -1
  return response + 1 if response.between?(1900, 3000)
  results[response][3]
end

def process_matches(matches)
  results = []
  matches.each do |match|
    matched_artist = match.artists.first.name
    matched_title = match.name
    matched_album = match.album.name
    matched_year = match.album.release_date[0..3]
    results << [matched_artist, matched_title, matched_album, matched_year]
  end
  results
end

def lookup_year(artist, title)
  matches = RSpotify::Track.search(artist + ' ' + title)
  
  if matches.empty?
    add_to_not_found_list(artist, title)
    puts "\nNo results found for #{artist} - #{title}\n"
    sleep 2
    return nil
  end

  system 'clear'
  puts "#{matches.count} matches found for #{artist} - #{title}"
  year_chooser(process_matches(matches))
end

def add_to_not_found_list(artist, title)
  File.open(filename, 'a') { |f| f.puts "#{artist} - #{title}" }
end

def filename
  'not_found.txt'
end

def update_year(artist, title)
  year = lookup_year(artist, title)
  return unless year
  system 'clear'
  sql = "UPDATE songlist SET albumyear = '#{year}' " \
        "WHERE id = #{id}"
  puts "Setting #{artist} - #{title} to [#{year}]"
  client.query(sql)
  sleep 2
end

system 'clear'
authenticate!
songs = songlist
songs.each { |i, a, t| update_song(i, a, t) }
