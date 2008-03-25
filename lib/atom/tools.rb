require 'atom/collection'

module Atom::Tools
  # fetch and parse a URL
  def http_to_feed url, complete_feed = false, http = Atom::HTTP.new
    feed = Atom::Feed.new url, http

    if complete_feed
      feed.get_everything!
    else
      feed.update!
    end

    feed.entries.map { |e| [nil, e] }
  end

  # parse a directory of entries
  def dir_to_feed path
    raise ArgumentError, "#{path} is not a directory" unless File.directory? path

    Dir[path+'/*.atom'].map do |e|
      slug = e.match(/.*\/(.*)\.atom/)[1]
      slug = nil if slug and slug.match /^0x/

      entry = Atom::Entry.parse(File.read(e))

      [slug, entry]
    end
  end

  def stdin_to_feed
    feed = Atom::Feed.parse $stdin

    slug_etc_from feed
  end

  def feed_to_http feed, url, http = Atom::HTTP.new
    coll = Atom::Collection.new url, http

    feed.each do |slug,entry|
      coll.post! entry, slug
    end
  end

  def feed_to_dir feed, path
    if File.exists? path
      raise "directory #{path} already exists"
    else
      Dir.mkdir path
    end

    feed.each do |slug,entry|
      e = entry.to_s

      new_filename = if slug
                       path + '/' + slug + '.atom'
                     else
                       path + '/0x' + MD5.new(e).hexdigest[0,8] + '.atom'
                     end

      File.open(new_filename, 'w') { |f| f.write e }
    end
  end

  def feed_to_stdout feed
    f = Atom::Feed.new

    feed.each do |slug,entry|
      f.entries << entry
    end

    puts f.to_s
  end

  def parse_input source, options
    if source.match /^http/
      http = Atom::HTTP.new

      setup_http http, options

      http_to_feed source, options[:complete], http
    elsif source == '-'
      stdin_to_feed
    else
      dir_to_feed source
    end
  end

  def write_output feed, dest, options
    if dest.match /^http/
      http = Atom::HTTP.new

      setup_http http, options

      feed_to_http feed, dest, http
    elsif dest == '-'
      feed_to_stdout feed
    else
      feed_to_dir feed, dest
    end
  end

  # set up some common OptionParser settings
  def atom_options opts, options
    opts.on('-u', '--user NAME', 'username for HTTP auth') { |u| options[:user] = u }
    opts.on('-v', '--verbose') { options[:verbose] = true }

    opts.on_tail('-h', '--help', 'Show this usage statement') { |h| puts opts; exit }
    opts.on_tail('-p', '--password [PASSWORD]', 'password for HTTP auth') do |p|
      p ||= begin
              require 'highline'

              HighLine.new.ask('Password: ') { |q| q.echo = false }
            rescue LoadError
              # Highline isn't installed, take the password anyway
              gets.chomp
            end

      options[:pass] = p
    end
  end

  def setup_http http, options
    if options[:user] and options[:pass]
      http.user = options[:user]
      http.pass = options[:pass]
    end
  end
end
