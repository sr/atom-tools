require File.dirname(__FILE__) + '/spec_helper'
require 'atom/entry'

describe Atom::Entry do
  describe 'when parsing' do
    before(:each) do
      @entry = Atom::Entry.parse(fixtures(:entry))
      @empty_entry = '<entry xmlns="http://www.w3.org/2005/Atom" />'
    end

    it 'should read & parse input from an Atomized REXML::Document' do
      input = mock('Atomized REXML::Document')
      input.should_receive(:to_atom_entry).and_return(Atom::Entry.new)
      Atom::Entry.parse(input).should be_an_instance_of(Atom::Entry)
    end

    it 'should read & parse input from an IO object' do
      input = mock('IO')
      input.should_receive(:read).and_return(@empty_entry)
      Atom::Entry.parse(input).should be_an_instance_of(Atom::Entry)
    end

    it 'should read & parse input from a string' do
      input = mock('string')
      input.should_receive(:to_s).and_return(@empty_entry)
      Atom::Entry.parse(input).should be_an_instance_of(Atom::Entry)
    end

    it 'should parse title correctly' do
      @entry.title.should be_an_instance_of(Atom::Text)
      @entry.title['type'].should == 'text'
      @entry.title.to_s.should == 'Atom draft-07 snapshot'
    end

    it 'should parse id correctly' do
      @entry.id.should == 'tag:example.org,2003:3.2397'
    end

    it 'should parse updated correctly' do
      @entry.updated.should == Time.parse('2005-07-31T12:29:29Z')
    end

    it 'should parse published correctly' do
      @entry.published.should == Time.parse('2003-12-13T08:29:29-04:00')
    end

    it 'should parse app:edited correctly' do
      @entry.edited.should == Time.parse('2005-07-31T12:29:29Z')
    end

    it 'should parse app:control/draft correctly' do
      @entry.draft?.should be_true
    end

    it 'should parse rights correctly' do
      @entry.rights.should be_an_instance_of(Atom::Text)
      @entry.rights['type'].should == 'text'
      @entry.rights.to_s.should == 'Copyright (c) 2003, Mark Pilgrim'
    end

    it 'should parse authors correctly' do
      @entry.authors.length.should == 1
      @entry.authors.first.name.should == 'Mark Pilgrim'
      @entry.authors.first.email.should == 'f8dy@example.com'
      @entry.authors.first.uri.should == 'http://example.org/'
    end

    it 'should parse contributors correctly' do
      @entry.contributors.length.should == 2
      @entry.contributors.first.name.should == 'Sam Ruby'
      @entry.contributors[1].name.should == 'Joe Gregorio'
    end

    it 'should parse content correctly' do
      @entry.content.should be_an_instance_of(Atom::Content)
      @entry.content['type'].should == 'xhtml'
      @entry.content.to_s.strip.should == '<p><i>[Update: The Atom draft is finished.]</i></p>'
    end

    it 'should parse summary correctly' do
      @entry.summary['type'].should == 'text'
      @entry.summary.to_s.should == 'Some text.'
    end

    it 'should parse links correctly' do
      @entry.links.length.should == 2
      alternates = @entry.links.select { |l| l['rel'] == 'alternate' }
      alternates.length.should == 1
      alternates.first['href'].should == 'http://example.org/2005/04/02/atom'
      alternates.first['type'].should == 'text/html'
      @entry.links.last['rel'].should == 'enclosure'
      @entry.links.last['href'].should == 'http://example.org/audio/ph34r_my_podcast.mp3'
      @entry.links.last['type'].should == 'audio/mpeg'
    end

    it 'should parse categories correctly' do
      @entry.categories.first['term'].should == 'ann'
      @entry.categories.first['scheme'].should == 'http://example.org/cats'
    end

    it 'should raise ParseError when invalid entry' do
      lambda { Atom::Entry.parse('<entry/>') }.should raise_error(Atom::ParseError)
    end
  end

  describe 'update element' do
    before(:each) do
      @entry = Atom::Entry.new
    end

    it 'should be nil if not defined' do
      @entry.updated.should be_nil
    end

    it 'should be definable' do
      @entry.updated = '1990-04-07'
      @entry.updated.should == Time.parse('1990-04-07')
    end

    it 'should be an xsd:DateTime' do
      @entry.updated = '1990-04-07'
      @entry.updated.to_s.should =~ /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/
    end

    it 'should set updated element when it receives #updated!' do
      @entry.updated!
      @entry.updated.should > Time.parse('1990-04-07')
    end
  end

  describe 'edited element' do
    before(:each) do
      @entry = Atom::Entry.new
    end

    it 'should be nil if not defined' do
      @entry.edited.should be_nil
    end

    it 'should be definable' do
      @entry.edited = '1990-04-07'
      @entry.edited.should == Time.parse('1990-04-07')
    end

    it 'should be an xsd:DateTime' do
      @entry.edited = '1990-04-07'
      @entry.edited.to_s.should =~ /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/
    end

    it 'should have APP namespace' do
      @entry.edited = '1990-04-07'
      @entry.to_xml.elements['/entry/edited'].namespace.should == Atom::PP_NS
    end

    it 'should set edited element when it receives #updated!' do
      @entry.edited!
      @entry.edited.should > Time.parse('1990-04-07')
    end
  end

  describe 'category element' do
    before(:each) do
      @entry = Atom::Entry.new
    end

    it 'should have no category on intializing' do
      @entry.categories.should be_empty
    end

    it 'should increase total count when adding new category' do
      @count = @entry.categories.length
      @entry.categories.new['term'] = 'foo'
      @entry.categories.length.should == @count + 1
    end

    it 'should find category' do
      category = @entry.categories.new
      category['scheme'] = 'http://example.org/categories'
      category['term'] = 'bar'
      @entry.categories.select { |c| c['scheme'] == 'http://example.org/categories' }.should == [category]
    end

    describe 'when using tags' do
      before(:each) do
        @tags = %w(chunky bacon ruby)
      end

      it 'should set categories from an array of tags' do
        @entry.tag_with(@tags)
        @entry.categories.length.should == 3
        @tags.each { |tag| @entry.categories.any? { |c| c['term'] == tag }.should be_true } 
      end

      it 'should set categories from a space-sperated string of tags' do
        @entry.tag_with(@tags.join(' '))
        @entry.categories.length.should == 3
        @tags.each { |tag| @entry.categories.any? { |c| c['term'] == tag }.should be_true }
      end

      it 'should be possible to specify the delimiter when passing tags as a string' do
        @entry.tag_with(@tags.join(','), ',')
        @entry.categories.length.should == 3
        @tags.each { |tag| @entry.categories.any? { |c| c['term'] == tag }.should be_true }
      end

      it 'should not create a category only once' do
        @entry.tag_with(@tags)
        @entry.tag_with(@tags.first)
        @entry.categories.length.should == 3
      end
    end
  end

  describe 'edit url' do
    before(:each) do
      @entry = Atom::Entry.new
    end

    it 'should be nil on initializing' do
      @entry.edit_url.should be_nil
    end

    it 'should be easily setable' do
      @entry.edit_url = 'http://example.org/entries/foo'
      @entry.edit_url.should == 'http://example.org/entries/foo'
    end
  end

  describe 'draft element' do
    before(:each) do
      @entry = Atom::Entry.new
    end

    it 'should not be a draft by default' do
      @entry.should_not be_draft
    end

    it 'should be setable using draft=' do
      @entry.draft = true
      @entry.should be_draft
      @entry.draft = false
      @entry.should_not be_draft
    end

    it 'should be setable using #draft!' do
      @entry.draft!
      @entry.should be_draft
    end

    it 'should have APP namespace' do
      @entry.draft!
      @entry.to_xml.elements['/entry/control/draft'].namespace.should == Atom::PP_NS
    end
  end
end
