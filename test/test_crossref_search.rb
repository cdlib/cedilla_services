require_relative './test_helper'
require_relative '../services/crossref_search.rb'

WebMock.disable_net_connect!(:allow_localhost => true)
LOGGER = Logger.new(STDOUT)

class CrossrefSearchTest < Minitest::Test
  
  def setup
    conf = nil
    if File.exists?(File.dirname(__FILE__) + '/config/app.yml')
      conf = YAML.load_file('./config/app.yml')
    else
      puts "Warning ./config/app.yml not found! Using ./config/app.yml.example instead."
      conf = YAML.load_file('./config/app.yml.example')
    end
    
    @config = conf['services']['crossref_search']
    
    @should_fail = [Cedilla::Citation.new({:genre => 'book', 
                                           :title => 'The Metamorphosis', 
                                           :isbn => '9781479157303',
                                           :extras => {'valid' => [true]},
                                           :authors => [Cedilla::Author.from_arbitrary_string('Kafka, Franz')]}),
                                        
                   Cedilla::Citation.new({:genre => 'journal', 
                                          :title => 'Journal of Hydrology'})]
                                        
    @should_pass = [Cedilla::Citation.new({:genre => 'article', 
                                          :doi => '10.1016/j.jhydrol.2010.07.004'}),
                                        
                  Cedilla::Citation.new({:genre => 'article', 
                                         :issn => '0022-1694'}),
                                        
                  Cedilla::Citation.new({:genre => 'article', 
                                         :pmid => '0022-1694'}),
                                        
                  Cedilla::Citation.new({:genre => 'article', 
                                         :eissn => '0022-1694'}),
                                                                                    
                  Cedilla::Citation.new({:genre => 'article', 
                                         :article_title => ' The impact of forest use and reforestation on soil hydraulic ...'})]
  end
  
  # -----------------------------------------------------------------------------------
  def test_validate_citation
    @service = CrossrefSearchService.new(@config)
    
    # CrossRef needs an ISSN, EISSN, PMID, DOI or an Article Title
    @should_pass.each do |citation|
      assert_equal true, @service.validate_citation(citation), "Was expecting the citation to pass the validation check!"
    end
    
    @should_fail.each do |citation|
      assert_equal false, @service.validate_citation(citation), "Was expecting the citation to fail the validation check!"
    end
  end
  
  # -----------------------------------------------------------------------------------
  def test_add_citation_to_target
    @service = CrossrefSearchService.new(@config)
    
    # CoverThing should append the identifier or article title to the url path
    @should_pass.each do |citation|
      query = citation.doi unless citation.doi.nil?
      query = citation.pmid if !citation.pmid.nil? and query.nil?
      query = citation.eissn if !citation.eissn.nil? and query.nil?
      query = citation.issn if !citation.issn.nil? and query.nil?
      query = citation.article_title if !citation.article_title.nil? and query.nil?
      
      target = "#{@config['target']}#{URI.escape(query.nil? ? '' : query)}#{@config['sort_param']}"
        
      assert_equal target, @service.add_citation_to_target(citation), "Was expecting citation to translate into a call to #{target}!"
    end
  end
  
  # -----------------------------------------------------------------------------------
  def test_process_response
    # CoverThing should append the ISBN to the url path
    @should_pass.each do |citation|
      @service = CrossrefSearchService.new(@config)
      
      # Setup the stub response
      # Response taken directly from CrossRef site: http://search.crossref.org/dois?q=10.1016/0022-1694(87)90185-5
      @service.response_status = 200
      @service.response_body = JSON.generate([{"doi" => "http://dx.doi.org/10.1016/0022-1694(87)90185-5",
                                "score" => 9.385611,
                                "normalizedScore" => 100,
                                "title" => "Chemical composition of rainfall and groundwater in recharge areas of the Bet Shean-Harod multiple aquifer system, Israel",
                                "fullCitation" => "E ROSENTHAL, 1987, 'Chemical composition of rainfall and groundwater in recharge areas of the Bet Shean-Harod multiple aquifer system, Israel', <i>Journal of Hydrology</i>, vol. 89, no. 3-4, pp. 329-352",
                                "year" => "1987"}]).to_s

      # Removed coins from the json response so that cedilla doesn't get called to translate it
                                #"coins" => "ctx_ver=Z39.88-2004&amp;rft_id=info%3Adoi%2Fhttp%3A%2F%2Fdx.doi.org%2F10.1016%2F0022-1694%2887%2990185-5&amp;rfr_id=info%3Asid%2Fcrossref.org%3Asearch&amp;rft.atitle=Chemical+composition+of+rainfall+and+groundwater+in+recharge+areas+of+the+Bet+Shean-Harod+multiple+aquifer+system%2C+Israel&amp;rft.jtitle=Journal+of+Hydrology&amp;rft.date=1987&amp;rft.volume=89&amp;rft.issue=3-4&amp;rft.spage=329&amp;rft.epage=352&amp;rft.aufirst=E&amp;rft.aulast=ROSENTHAL&amp;rft_val_fmt=info%3Aofi%2Ffmt%3Akev%3Amtx%3Ajournal&amp;rft.genre=article&amp;rft.au=E+ROSENTHAL",
                                
      
      # Add the citation to the target to setup the return url and then call process_response
      @service.add_citation_to_target(citation)
      new_citation = @service.process_response
      
      assert_equal "http://dx.doi.org/10.1016/0022-1694(87)90185-5", new_citation.doi, "Was expecting the doi to match the stub!" if citation.doi.nil?
      assert_equal "Chemical composition of rainfall and groundwater in recharge areas of the Bet Shean-Harod multiple aquifer system, Israel", new_citation.article_title, "Was expecting the article_title to match the stub!" if citation.article_title.nil?
    end
  end
  
end

# -----------------------------------------------------
# Patch the service so we can add a stub HTTP response
# -----------------------------------------------------
class CrossrefSearchService
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