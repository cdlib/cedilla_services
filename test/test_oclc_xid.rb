require_relative './test_helper'
require_relative '../services/oclc_xid.rb'

WebMock.disable_net_connect!(:allow_localhost => true)
LOGGER = Logger.new(STDOUT)

class OclcXidTest < Minitest::Test
  
  def setup
    conf = nil
    if File.exists?(File.dirname(__FILE__) + '/config/app.yml')
      conf = YAML.load_file('./config/app.yml')
    else
      puts "Warning ./config/app.yml not found! Using ./config/app.yml.example instead."
      conf = YAML.load_file('./config/app.yml.example')
    end
    
    @config = conf['services']['oclc_xid']
    
    @citations = [Cedilla::Citation.new({:genre => 'book', 
                                        :title => 'The Metamorphosis', 
                                        :isbn => '9781479157303',
                                        :extras => {'valid' => [true]},
                                        :authors => [Cedilla::Author.from_arbitrary_string('Kafka, Franz')]}),
                                        
                  Cedilla::Citation.new({:genre => 'book', 
                                        :title => 'Franz Kafka: The Complete Stories', 
                                        :eisbn => '9780805210552',
                                        :publisher => 'Schocken Books Inc.; Reprint edition (November 14, 1995)',
                                        :language => 'English',
                                        :pages => '488 pages',
                                        :extras => {'valid' => [true]},
                                        :authors => [Cedilla::Author.from_arbitrary_string('Kafka, Franz')]}),
                                        
                  Cedilla::Citation.new({:genre => 'journal',
                                         :title => 'The European Physical Journal D',
                                         :issn => '1434-6060',
                                         :extras => {'valid' => [true]}}),
                                         
                 Cedilla::Citation.new({:genre => 'journal',
                                        :title => 'The European Physical Journal B',
                                        :eissn => '1434-6036',
                                        :extras => {'valid' => [true]}}),
                        
                  Cedilla::Citation.new({:genre => 'article',
                                         :journal_title => 'The European Physical Journal D',
                                         :article_title => 'Relativistic Vlasov code development for high energy density plasmas',
                                         :issn => '1434-6060',
                                         :extras => {'valid' => [true]},
                                         :authors => [Cedilla::Author.from_arbitrary_string('Sizhong Wu'), 
                                                      Cedilla::Author.from_arbitrary_string('Hua Zhang'),
                                                      Cedilla::Author.from_arbitrary_string('Cangtao Zhou')]}),
                                                      
                  Cedilla::Citation.new({:genre => 'article', 
                                        :title => 'Authority, Autonomy, and Choice: The Role of Consent in the Moral and Political Visions of Franz Kafka and Richard Posner', 
                                        :doi => '10.2307/1341128',
                                        :publisher => 'The Harvard Law Review Association',
                                        :start_page => '384',
                                        :end_page => '428',
                                        :extras => {'valid' => [false]},
                                        :authors => [Cedilla::Author.from_arbitrary_string('Robin West')]})]
  end
  
  # -----------------------------------------------------------------------------------
  def test_validate_citation
    @service = OclcXidService.new(@config)
    
    # Oclc Xid needs an ISBN or ISSN 
    @citations.each do |citation|
      assert_equal citation.extras['valid'][0], @service.validate_citation(citation), "Was expecting #{citation.title} to #{citation.extras['valid'][0] ? 'pass' : 'fail'} the validartion check!"
    end
  end
  
  # -----------------------------------------------------------------------------------
  def test_add_citation_to_target
    @service = OclcXidService.new(@config)
    
    # Oclc Xid should append the ISBN or ISSN to the url path
    @citations.each do |citation|
      target = "#{@config['target']}?#{@config['query_string']}"
      
      if citation.extras['valid'][0]
        if (!citation.isbn.nil? or !citation.eisbn.nil?)
          target = target.sub('{idType}', 'xisbn').sub('?', "isbn/#{citation.isbn.nil? ? citation.eisbn : citation.isbn}?")
          
        elsif (!citation.issn.nil? or !citation.eissn.nil?)
          target = target.sub('{idType}', 'xissn').sub('?', "issn/#{citation.issn.nil? ? citation.eissn : citation.issn}?")
        end
        
        assert_equal target, @service.add_citation_to_target(citation), "Was expecting #{citation.title} to translate into a call to #{target}!"
      end
    end
  end
  
  # -----------------------------------------------------------------------------------
  def test_process_response
    # Oclc Xid should append the ISBN to the url path
    @citations.each do |citation|
      @service = OclcXidService.new(@config)
      
      if citation.extras['valid'][0]
        # Setup the stub response
        @service.response_status = 200
        @service.response_headers = {'content-type' => 'application/json'}
        @service.response_body = JSON.generate({"stat" => "ok",
                                                "list" => [{"lang" => "English",
                                                            "city" => "Geneva",
                                                            "author" => "by Jane Doe",
                                                            "oclc" => "12345", 
                                                            "foo" => "bar"},
                                                           {"lang" => "French",
                                                            "city" => "Brussels",
                                                            "author" => "by Sara Doe",
                                                            "oclc" => "67890", 
                                                            "foo" => "bar2"}]})
      
        # Add the citation to the target to setup the return url and then call process_response
        @service.add_citation_to_target(citation)
        new_citation = @service.process_response
        
        assert !new_citation.oclc.nil?, "Was expecting the oclc for #{citation.title} to be available!"
      else        
        # Setup the stub response
        @service.response_status = 200
        @service.response_headers = {'content-type' => 'application/json'}
        @service.response_body = JSON.generate({"stat" => "none found",
                                                "list" => []})
      
        # Add the citation to the target to setup the return url and then call process_response
        @service.add_citation_to_target(citation)
        new_citation = @service.process_response
        
        assert new_citation.oclc.nil?, "Was expecting the oclc for #{citation.title} to be nil but was #{new_citation.oclc}!"
      end
      
    end
  end
  
end

# -----------------------------------------------------
# Patch the service so we can add a stub HTTP response
# -----------------------------------------------------
class OclcXidService
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