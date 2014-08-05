require_relative './test_helper'
require_relative '../services/cover_thing.rb'

WebMock.disable_net_connect!(:allow_localhost => true)
LOGGER = Logger.new(STDOUT)

class CoverThingTest < Minitest::Test
  
  def setup
    @config = YAML.load_file('./config/app.yml')['services']['cover_thing']
    
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
    @service = CoverThingService.new(@config)
    
    # CoverThing needs an ISBN so make sure the citations above that have an ISBN pass and the others fail
    @citations.each do |citation|
      assert_equal citation.extras['valid'][0], @service.validate_citation(citation), "Was expecting #{citation.title} to #{citation.extras['valid'][0] ? 'pass' : 'fail'} the validartion check!"
    end
  end
  
  # -----------------------------------------------------------------------------------
  def test_add_citation_to_target
    @service = CoverThingService.new(@config)
    
    # CoverThing should append the ISBN to the url path
    @citations.each do |citation|
      if citation.extras['valid'][0]
        target = "#{@config['target']}#{citation.isbn.nil? ? citation.eisbn.gsub(/[^\d]/, '') : citation.isbn.gsub(/[^\d]/, '')}"
        
        assert_equal target, @service.add_citation_to_target(citation), "Was expecting #{citation.title} to translate into a call to #{target}!"
      end
    end
  end
  
  # -----------------------------------------------------------------------------------
  def test_process_response
    # CoverThing should append the ISBN to the url path
    @citations.each do |citation|
      @service = CoverThingService.new(@config)
      
      # Setup the stub response
      @service.response_status = 200
      @service.response_headers = {'content-length' => (citation.extras['valid'][0] ? 456 : 43)}
      @service.response_body = (citation.extras['valid'][0] ? "We found an image!!" : '')
      
      # Add the citation to the target to setup the return url and then call process_response
      @service.add_citation_to_target(citation)
      new_citation = @service.process_response
      
      if citation.extras['valid'][0]
        assert !new_citation.sample_cover_image.nil?, "Was expecting the sample_cover_image for #{citation.title} to be available!"
      else
        assert new_citation.sample_cover_image.nil?, "Was expecting the sample_cover_image for #{citation.title} to be un-available!"
      end
      
    end
  end
  
end

# -----------------------------------------------------
# Patch the service so we can add a stub HTTP response
# -----------------------------------------------------
class CoverThingService
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