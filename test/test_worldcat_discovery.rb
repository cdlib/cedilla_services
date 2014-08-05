require_relative './test_helper'
require_relative '../services/worldcat_discovery.rb'

WebMock.disable_net_connect!(:allow_localhost => true)
LOGGER = Logger.new(STDOUT)

class WorldcatDiscoveryTest < Minitest::Test
  
  def setup
    conf = nil
    if File.exists?(File.dirname(__FILE__) + '/config/app.yml')
      conf = YAML.load_file('./config/app.yml')
    else
      puts "Warning ./config/app.yml not found! Using ./config/app.yml.example instead."
      conf = YAML.load_file('./config/app.yml.example')
    end
    
    @config = conf['services']['worldcat_discovery']
      
    @citations = [Cedilla::Citation.new({:genre => 'book', 
                                        :title => 'The Metamorphosis', 
                                        :isbn => '9781479157303',
                                        :extras => {'valid' => [true], 'reason' => ['has isbn']},
                                        :authors => [Cedilla::Author.from_arbitrary_string('Kafka, Franz')]}),
                                        
                  Cedilla::Citation.new({:genre => 'book', 
                                        :title => 'Franz Kafka: The Complete Stories', 
                                        :eisbn => '9780805210552',
                                        :publisher => 'Schocken Books Inc.; Reprint edition (November 14, 1995)',
                                        :language => 'English',
                                        :pages => '488 pages',
                                        :extras => {'valid' => [true], 'reason' => ['has eisbn']},
                                        :authors => [Cedilla::Author.from_arbitrary_string('Kafka, Franz')]}),
                                        
                  Cedilla::Citation.new({:genre => 'journal',
                                         :title => 'The European Physical Journal D',
                                         :issn => '1434-6060',
                                         :extras => {'valid' => [true], 'reason' => ['has issn']}}),
                                         
                  Cedilla::Citation.new({:genre => 'journal',
                                         :title => 'The European Physical Journal B',
                                         :eissn => '1434-6036',
                                         :extras => {'valid' => [true], 'reason' => ['has eissn']}}),
                        
                  Cedilla::Citation.new({:genre => 'journal',
                                         :title => 'The European Physical Journal B',
                                         :lccn => '12345',
                                         :extras => {'valid' => [true], 'reason' => ['has lccn']}}),
                                         
                  Cedilla::Citation.new({:genre => 'journal',
                                         :title => 'The European Physical Journal B',
                                         :oclc => '67890',
                                         :extras => {'valid' => [true], 'reason' => ['has oclc']}}),
                                         
                  Cedilla::Citation.new({:genre => 'journal',
                                         :title => 'The European Physical Journal B',
                                         :extras => {'valid' => [true], 'reason' => ['has author + title']},
                                         :authors => [Cedilla::Author.from_arbitrary_string('Kafka, Franz')]}),
                                         
                  Cedilla::Citation.new({:genre => 'journal',
                                         :book_title => 'The European Physical Journal B',
                                         :extras => {'valid' => [false], 'reason' => ['no authors']}}),
                                                               
                  Cedilla::Citation.new({:genre => 'article',
                                         :journal_title => 'The European Physical Journal D',
                                         :article_title => 'Relativistic Vlasov code development for high energy density plasmas',
                                         :doi => '12345',
                                         :extras => {'valid' => [true], 'reason' => ['has article_title']},
                                         :authors => [Cedilla::Author.from_arbitrary_string('Sizhong Wu')]}),
                                                      
                  Cedilla::Citation.new({:genre => 'article', 
                                        :doi => '10.2307/1341128',
                                        :publisher => 'The Harvard Law Review Association',
                                        :start_page => '384',
                                        :end_page => '428',
                                        :extras => {'valid' => [false], 'reason' => ['no titles']},
                                        :authors => [Cedilla::Author.from_arbitrary_string('Robin West')]})]
                                        
    # Stub the call to the service because we need to test process_request
    # Response obtained directly from the contents of the WorldcatDiscovery submodule!!
    @citations.each do |citation|
      if citation.extras['valid']
        last_name = (citation.authors.first.nil? ? '' : citation.authors.first.last_name)
        title = (citation.article_title.nil? ? citation.journal_title.nil? ? citation.book_title.nil? ? citation.title.nil? ? '' : citation.title : citation.book_title : citation.journal_title : citation.article_title)
      
        if !citation.oclc.nil?
          stub_request(:get, "#{@config['target']}/data/#{citation.oclc}").
                      with(:headers => {'Accept'=>'application/rdf+xml', 'Accept-Encoding'=>'gzip, deflate', 'Authorization'=>'Bearer', 'User-Agent'=>'WorldCat::Discovery Ruby gem / 0.1.0'}).
                      to_return(:status => 200, 
                                :body => File.new("#{File.expand_path(File.dirname(__FILE__)).sub('test', 'vendor/worldcat-discovery-ruby/spec/support/responses/bib_search.rdf')}", 'r'), 
                                :headers => {'Content-Type' => 'application/rdf+xml;charset=UTF-8'})
                                
        elsif last_name != '' and title != ''
          stub_request(:get, "#{@config['target']}/search?au=#{URI.escape(last_name)}&facets=inLanguage:10&q=#{URI.escape(title)}&startNum=0").
                      with(:headers => {'Accept'=>'application/rdf+xml', 'Accept-Encoding'=>'gzip, deflate', 'Authorization'=>'Bearer', 'User-Agent'=>'WorldCat::Discovery Ruby gem / 0.1.0'}).
                      to_return(:status => 200, 
                                :body => File.new("#{File.expand_path(File.dirname(__FILE__)).sub('test', 'vendor/worldcat-discovery-ruby/spec/support/responses/bib_search.rdf')}", 'r'), 
                                :headers => {'Content-Type' => 'application/rdf+xml;charset=UTF-8'})
        elsif title != ''
          stub_request(:get, "#{@config['target']}/search?facets=inLanguage:10&q=#{URI.escape(title)}&startNum=0").
                      with(:headers => {'Accept'=>'application/rdf+xml', 'Accept-Encoding'=>'gzip, deflate', 'Authorization'=>'Bearer', 'User-Agent'=>'WorldCat::Discovery Ruby gem / 0.1.0'}).
                      to_return(:status => 200, 
                                :body => File.new("#{File.expand_path(File.dirname(__FILE__)).sub('test', 'vendor/worldcat-discovery-ruby/spec/support/responses/bib_search.rdf')}", 'r'), 
                                :headers => {'Content-Type' => 'application/rdf+xml;charset=UTF-8'})
                                
        else
          id = (citation.lccn.nil? ? citation.oclc.nil? ? '' : citation.oclc : citation.lccn)
        end
      end
    end
  end

  # -----------------------------------------------------------------------------------
  def test_validate_citation
    @service = WorldcatDiscoveryService.new(@config)
    
    # WorldcatDiscovery needs an ISBN, ISSN, OCLC, LCCN, or a title and author!
    @citations.each do |citation|
      assert_equal citation.extras['valid'][0], @service.validate_citation(citation), "Was expecting citation to #{citation.extras['valid'][0] ? 'pass' : 'fail'} the validation check due to '#{citation.extras['reason'][0]}'!"
    end
  end
  
  # -----------------------------------------------------------------------------------
  def test_process_request
    # WorldcatDiscovery overrides the request process because it uses the OCLC Developer
    # Network's Worldcat Discovery ruby project which handles the communication with the
    # OCLC servers and provides an interface to the RDF graph data
    @service = WorldcatDiscoveryService.new(@config)
    
    # WorldcatDiscovery should append the ISBN or ISSN to the url path
    @citations.each do |citation|
      request = Cedilla::Request.new({:requestor_ip => '127.0.0.1', 
                                      :citation => citation})
      
      if citation.extras['valid'][0]
        response = @service.process_request(request, {})
        
        assert !response['citations'].nil?, "Was expecting a response from the WorldcatDiscovery Service!"
      end
    end
  end
  
end

# --------------------------------------------------------------------------------------
# Must mock service and OCLC::Auth::WSKey so it doesn't try to authenticate because
# we cannot stub the auth request because it changes everytime including time stamps!
# --------------------------------------------------------------------------------------
class WorldcatDiscoveryService
  def initialize(config)
    wskey = OCLC::Auth::WSKey.new(config['auth_key'], config['auth_secret'], :services => ['WorldCatDiscoveryAPI'])
    WorldCat::Discovery.configure(wskey, config['auth_institution'], config['auth_institution'])
  end
end

module OCLC
  module Auth
    class WSKey
      def initialize(key, secret, options)
        @services = options
        true
      end
      
      def client_credentials_token(authenticating_institution_id, context_institution_id, options = {})
        token = OCLC::Auth::AccessToken.new('client_credentials', @services.first, authenticating_institution_id, context_institution_id)
        #token.create!(self, options)
        token
      end
    end
  end
end

module OCLC
  module Auth
    class AccessToken
      def expired?
        false
      end
    end
  end
end
