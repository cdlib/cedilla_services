require_relative './test_helper'
require_relative '../services/internet_archive.rb'

WebMock.disable_net_connect!(:allow_localhost => true)
LOGGER = Logger.new(STDOUT)

class InternetArchiveTest < Minitest::Test
  
  def setup
    @config = YAML.load_file('./config/app.yml')['services']['internet_archive']
    
    @citations = []
    
    # We only check IA for books at this point
    titles = [:title, :book_title]
    
    titles.each do |sym|
      @citations << Cedilla::Citation.new({:genre => (sym.id2name.include?('_') ? "#{sym.id2name.slice(0, sym.id2name.index('_'))}" : 'book'), 
                                          sym => 'Franz Kafka: The Complete Stories', 
                                          :publisher => 'Schocken Books Inc.; Reprint edition (November 14, 1995)',
                                          :language => 'English',
                                          :pages => '488 pages',
                                          :extras => {'valid' => [true], 'reason' => ["has author and #{sym.id2name}"]},
                                          :authors => [Cedilla::Author.from_arbitrary_string('Kafka, Franz')]})
    end                              
    
    @citations << Cedilla::Citation.new({:genre => 'article', 
                                        :title => 'Authority, Autonomy, and Choice: The Role of Consent in the Moral and Political Visions of Franz Kafka and Richard Posner', 
                                        :publisher => 'The Harvard Law Review Association',
                                        :start_page => '384',
                                        :end_page => '428',
                                        :extras => {'valid' => [false], 'reason' => ['has NO author!']}})
                                        
    @citations << Cedilla::Citation.new({:genre => 'book', 
                                        :publisher => 'Schocken Books Inc.; Reprint edition (November 14, 1995)',
                                        :language => 'English',
                                        :pages => '488 pages',
                                        :extras => {'valid' => [false], 'reason' => ['has NO title!']},
                                        :authors => [Cedilla::Author.from_arbitrary_string('Kafka, Franz')]})
                                        
    @citations << Cedilla::Citation.new({:genre => 'book', 
                                        :chapter_title => 'Chapter One',
                                        :publisher => 'Schocken Books Inc.; Reprint edition (November 14, 1995)',
                                        :language => 'English',
                                        :pages => '488 pages',
                                        :extras => {'valid' => [false], 'reason' => ['ONLY has a chapter_title!']},
                                        :authors => [Cedilla::Author.from_arbitrary_string('Kafka, Franz')]})
                                        
    @json_response = '{"response":{"numFound":3,"start":0,"docs":[' +
                          '{"mediatype":"texts","description":"Frank Herbert - Dune - V 1 - Dune Celelalte volume:","title":"Frank Herbert - Dune - V 1 - Dune (Romanian language)","publicdate":"2013-10-15T10:27:50Z","licenseurl":"http://creativecommons.org/publicdomain/zero/1.0/","downloads":821,"identifier":"FrankHerbertDuneV1Dune_in_romanian","subject":["Frank Herbert","Dune","V 1","carte","romana","pdf","online","ro-books","10000 carti","romanian"],"format":["Abbyy GZ","Animated GIF","Archive BitTorrent","DjVu","DjVuTXT","Djvu XML","EPUB","Metadata","Scandata","Single Page Processed JP2 ZIP","Text PDF"],"language":["Romanian"],"creator":["Frank Herbert"]},' +
                          '{"publicdate":"2012-09-25T11:16:20Z","title":"Dune: House Harkonnen","mediatype":"data","date":"2000-01-01T00:00:00Z","downloads":13,"identifier":"mbid-fad87f4f-fcc8-4ebc-b082-661a0705d229","format":["Archive BitTorrent","JSON","Metadata","Metadata Log","MusicBrainz Metadata"],"language":["eng"],"creator":["Frank Herbert","Brian Herbert","Kevin J. Anderson"]},' +
                          '{"mediatype":"texts","title":"Frank Herbert - Dune (Romanian Language / Limba Romana)","description":"Frank Herbert - Dune (Romanian Language / Limba Romana) Celelalte volume:","licenseurl":"http://creativecommons.org/publicdomain/zero/1.0/","publicdate":"2012-09-17T16:25:07Z","downloads":4916,"identifier":"FrankHerbert-Dune","subject":["Frank Herbert","Dune","ro-books","altfeldecarte"],"format":["Abbyy GZ","Animated GIF","Archive BitTorrent","DjVu","DjVuTXT","Djvu XML","EPUB","Metadata","Scandata","Single Page Processed JP2 ZIP","Text PDF","Word Document"],"language":["Romanian"],"creator":["Frank Herbert"]}' +
                        ']}}'
                    
    @json_no_response = '{"response":{"numFound":0,"start":0,"docs":[]}}'
  end
  
  # -----------------------------------------------------------------------------------
  def test_validate_citation
    @service = InternetArchiveService.new(@config)
    
    # InternetArchive needs an identifier or an author and title
    @citations.each do |citation|
      assert_equal citation.extras['valid'][0], @service.validate_citation(citation), "Was expecting #{citation.extras['reason'][0]} to #{citation.extras['valid'][0] ? 'pass' : 'fail'} the validation check because #{citation.extras['reason'][0]} its validation check!"
    end
  end
  
  # -----------------------------------------------------------------------------------
  def test_add_citation_to_target
    @service = InternetArchiveService.new(@config)
        
    # InternetArchive should append the title and author to the URI
    @citations.each do |citation|
      if citation.extras['valid'][0]
        title = (citation.article_title.nil? ? citation.journal_title.nil? ? citation.book_title.nil? ? citation.title.nil? ? '' : citation.title : citation.book_title : citation.journal_title : citation.article_title)
        author = (citation.authors.first.nil? ? '' : citation.authors.first.last_name)
        
        query = "#{@config['citation_uri']}".sub('?', URI.escape(title)).
                                             sub('?', URI.escape(author.chomp(',')))
        
        target = "#{@config['target']}#{@config['query_string']}&#{query}"
        
        response = @service.add_citation_to_target(citation)
        
        assert_equal target, response, "Was expecting to see #{target} for the #{citation.extras['reason'][0]} test but got #{response}!"
      end
    end
  end
  
  # -----------------------------------------------------------------------------------
  def test_process_response
    # InternetArchive should append the ISBN to the url path
    @citations.each do |citation|
      @service = InternetArchiveService.new(@config)
      
      # Setup the stub response
      @service.response_status = 200
      @service.response_headers = {'Content-Type' => 'application/json'}
      @service.response_body = (citation.extras['valid'][0] ? @json_response : @json_no_response)
      
      new_citation = @service.process_response
      
      if citation.extras['valid'][0]
        assert !new_citation.resources.empty?, "Was expecting a resource to have been found for #{citation.extras['reason'][0]} test to be available!"
      else
        puts new_citation.resources
        
        assert new_citation.resources.empty?, "Was expecting no resources for #{citation.extras['reason'][0]} test to be un-available!"
      end
      
    end
  end
  
end

# -----------------------------------------------------
# Patch the service so we can add a stub HTTP response
# -----------------------------------------------------
class InternetArchiveService
  def response_body=(val)
    @response_body = val || ''
  end
  
  def response_headers=(hash)
    @response_headers = hash || {}
  end
  
  def response_status=(code)
    @response_status = code || 500
  end
end