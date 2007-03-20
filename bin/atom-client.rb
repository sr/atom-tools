#!/usr/bin/ruby

require "optparse"

options = {}

OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [options]"

  opts.on("-c", "--coll-url [URL]", "URL of the collection you would like to manipulate") do |url|
    options[:url] = url
  end

  opts.on("-u", "--user [USERNAME]", "Username to authenticate with") do |user|
    options[:user] = user
  end

  opts.on("-p", "--password [PASSWORD]", "Password to authenticate with") do |pass|
    options[:pass] = pass
  end

  opts.on_tail("-h", "--help", "Show this message") do
    puts opts
    exit
  end
end.parse!

require "tempfile"

require "atom/yaml"
require "atom/service"
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

    updated!
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
   
    # human readability
    yaml.delete "id"

    if yaml["links"]
      yaml["links"].find_all { |l| l["rel"] == "alternate" or l["rel"] == "edit" }.each { |l| yaml["links"].delete(l) }
      yaml.delete("links") if yaml["links"].empty?
    end
    
    new_yaml, entry = write_entry(yaml.to_yaml)
    
    entry.id = self.id

    [new_yaml["slug"], entry]
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
      puts "You didn't edit anything, aborting."
      exit
    end

    yaml = YAML.load(edited)

    entry = Atom::Entry.from_yaml yaml

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

  [yaml, entry]
end

module Atom
  class InvalidEntry < RuntimeError; end
end

EDITOR = ENV["EDITOR"] || "env vim"

http = Atom::HTTP.new

url = if options[:url]
  options[:url]
else
  yaml = YAML.load(File.read("#{ENV["HOME"]}/.atom-client"))
  collections = yaml["collections"]

  puts "which collection?"

  collections.keys.each_with_index do |name,index|
    puts "#{index}: #{name}"
  end

  tmp = choose_from collections.values

  http.user = tmp["user"] if tmp["user"]
  http.pass = tmp["pass"] if tmp["pass"]

  tmp["url"]
end

http.user = options[:user] if options[:user]
http.pass = options[:pass] if options[:pass]

# this is where all the Atom stuff starts

coll = Atom::Collection.new(url, http)

# XXX generate a real id
CLIENT_ID = "http://necronomicorp.com/nil"

new = lambda do
  entry = Atom::Entry.new
  
  entry.title = ""
  entry.content = ""

  slug, entry = entry.edit

  entry.id = CLIENT_ID
  entry.published = Time.now.iso8601

  res = coll.post! entry, slug

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

  raise "this entry has no edit link" unless url

  entry = http.get_atom_entry url

  slug, new_entry = entry.edit

  res = coll.put! new_entry, url

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
