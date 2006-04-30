#!/usr/bin/ruby

# syntax: ./atom-client.rb <introspection-url> [username] [password]
#   a 

require "tempfile"

require "atom/yaml"
require "atom/app"
require "atom/http"

require "rubygems"
require "bluecloth"

require "time"

require 'yaml'

class Tempfile
  def edit_externally
    self.close

    system("#{EDITOR} #{self.path}")

    self.open
  end
end

class String
  def edit_externally
    tempfile = Tempfile.new("entry")
    tempfile.puts self

    tempfile.edit_externally

    ret = tempfile.read
    tempfile.delete

    ret
  end
end

class Atom::Entry
  def prepare_for_output
    filter_hook

    update!
  end

  def filter_hook
    # so much for actual text content...
    if @content and @content["type"] == "text"
      self.content = BlueCloth.new( @content.to_s ).to_html
      @content["type"] = "xhtml"
    end
  end

  def edit
    yaml = YAML.load(self.to_yaml)
    
    # humans don't care about these things
    yaml.delete "id"

    if yaml["links"]
      yaml["links"].delete(yaml["links"].find { |l| l["rel"] == "edit" })
      yaml["links"].delete(yaml["links"].find { |l| l["rel"] == "alternate" })
      yaml.delete("links") if yaml["links"].empty?
    end

    entry = write_entry(yaml.to_yaml)
    # the id doesn't appear in YAML, it should remain the same
    entry.id = self.id

    entry
  end
end

# maybe this should handle displaying the list too.
def choose_from list
  item = nil
  itemno = nil

  # oh wow this is pathetic
  until item
    if itemno
      puts "try picking a number on the list."
    end

    print "? "
    itemno = $stdin.gets.chomp

    item = list[itemno.to_i]
  end

  item
end

def choose_collection server
  puts "which collection?"

  collections = []

  # still lame
  server.collections.each_with_index do |pair, index|
    collections << pair.last

    puts "#{index}: #{pair.first}"
  end

  choose_from collections
end

def choose_entry_url coll
  puts "which entry?"

  coll.entries.each_with_index do |entry, index|
    puts "#{index}: #{entry.title}"
  end

  entry = choose_from coll.entries

  edit_link = entry.links.find do |link|
    link["rel"] = "edit"
  end

  edit_link["href"]
end

def write_entry(editstring = "")
  begin
    edited = editstring.edit_externally

    if edited == editstring
      puts "unchanged content, aborted"
      exit
    end

    entry = Atom::Entry.from_yaml edited

    entry.prepare_for_output

    # XXX disabled until the APP WG can decide what a valid entry is
=begin
    valid, message = entry.valid?
    unless valid
      print "entry is invalid (#{message}). post anyway? (y/n)? "
      (gets.chomp == "y") || (raise Atom::InvalidEntry.new)
    end
=end

    # this has to be here ATM to we can detect malformed atom:content
    puts entry.to_s
  rescue ArgumentError,REXML::ParseException => e
    puts e
    
    puts "press enter to edit again..."
    $stdin.gets

    editstring = edited

    retry
  rescue Atom::InvalidEntry
    editstring = edited
    retry
  end

  entry
end

module Atom
  class InvalidEntry < RuntimeError
  end
end

EDITOR = ENV["EDITOR"] || "env vim"

# now that i'm supporting -07 the interface has been shittified. apologies.
introspection_url = ARGV[0]

http = Atom::HTTP.new
http.user = ARGV[1]
http.pass = ARGV[2]

server = Atom::App.new(introspection_url, http)

coll = choose_collection server

# XXX the server should *probably* replace this, but who knows yet?
CLIENT_ID = "http://necronomicorp.com/dev/null"

new = lambda do
  entry = Atom::Entry.new
  
  entry.title = ""
  entry.content = ""

  entry = entry.edit

  entry.id = CLIENT_ID
  entry.published = Time.now.iso8601

  res = coll.post! entry

  # XXX error recovery here, lost updates suck
  puts res.body
end

edit = lambda do
  coll.update!

  coll.entries.each_with_index do |entry,idx|
    puts "#{idx}: #{entry.title}"
  end

  entry = choose_from(coll.entries) { |entry| entry.title }

  url = entry.edit_url

  entry = coll.get_url url

  res = coll.put! entry.edit, url

  # XXX error recovery here, lost updates suck
  puts res.body
end

delete = lambda do
  coll.update!
  
  coll.entries.each_with_index do |entry,idx|
    puts "#{idx} #{entry.title}"
  end

  entry = choose_from(coll.entries)
  res = coll.delete! entry

  puts res.body
end

actions = [ new, edit, delete ]

puts "0: new entry"
puts "1: edit entry"
puts "2: delete entry"

choose_from(actions).call
