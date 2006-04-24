#!/usr/bin/ruby

require "atom/collection"

# syntax: ./atom-post.rb <collection-url> [username] [password]
#   posts STDIN to the collection at <collection-url>.
#   very simplistic, could use eg. -t <title>, get author from environment, &c.

http = Atom::HTTP.new
http.user = ARGV[1]
http.pass = ARGV[2]

coll = Atom::Collection.new(ARGV[0], http)

text = ""

while line = STDIN.gets
  text += line
end

entry = Atom::Entry.new 

entry.content = text

res = coll.post! entry

puts res.inspect
