require_relative './test_helper'
require_relative '../services/sfx.rb'

WebMock.disable_net_connect!(:allow_localhost => true)
LOGGER = Logger.new(STDOUT)

class SfxTest < Minitest::Test
  
  def setup
    @config = YAML.load_file('./config/app.yml')['services']['sfx']
    
    @citations = []
    
    identifiers = [:issn, :eissn, :isbn, :eisbn, :isbn, :eisbn, :oclc, :lccn, :doi,
                   :pmid, :coden, :sici, :bici, :document_id, :dissertation_number,
                   :bibcode, :eric, :oai, :nbn, :hdl]
                   
    identifiers.each do |sym|               
      @citations << Cedilla::Citation.new({:genre => 'book', 
                                           :title => 'The Metamorphosis', 
                                           sym => '9781479157303',
                                           :extras => {'valid' => [true], 'reason' => ["has #{sym.id2name}"]}})
    end                                        
    
    titles = [:title, :book_title, :journal_title, :article_title]
    
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
                                        :extras => {'valid' => [false], 'reason' => ['has NO author or identifier!']}})
                                        
    @citations << Cedilla::Citation.new({:genre => 'book', 
                                        :publisher => 'Schocken Books Inc.; Reprint edition (November 14, 1995)',
                                        :language => 'English',
                                        :pages => '488 pages',
                                        :extras => {'valid' => [false], 'reason' => ['has NO title or identifier!']},
                                        :authors => [Cedilla::Author.from_arbitrary_string('Kafka, Franz')]})
                                        
    @citations << Cedilla::Citation.new({:genre => 'book', 
                                        :chapter_title => 'Chapter One',
                                        :publisher => 'Schocken Books Inc.; Reprint edition (November 14, 1995)',
                                        :language => 'English',
                                        :pages => '488 pages',
                                        :extras => {'valid' => [false], 'reason' => ['ONLY has a chapter_title!']},
                                        :authors => [Cedilla::Author.from_arbitrary_string('Kafka, Franz')]})
                                        
    @sfx_response = '<ctx_obj_set>
                       <ctx_obj identifier="">
                         <ctx_obj_attributes></ctx_obj_attributes>
                         <ctx_obj_targets>
                           <target>
                            <target_name>SPRINGER_LINK_BOOKS_COMPLETE</target_name>
                            <target_public_name>SpringerLink Books Complete</target_public_name>
                            <object_portfolio_id>3390000000115957</object_portfolio_id>
                            <target_id>1000000000001381</target_id>
                            <target_service_id>1000000000002021</target_service_id>
                            <service_type>getFullTxt</service_type>
                            <parser>Springer::BOOKS</parser>
                            <parse_param>url=http://link.springer.com &amp; url2=http://rd.springer.com &amp; code=&amp;bkey=10.1007/978-1-4614-3612-6</parse_param>
                            <proxy>no</proxy>
                            <crossref>yes</crossref>
                            <timediff_warning></timediff_warning>
                            <note></note>
                            <authentication></authentication>
                            <char_set>iso-8859-1</char_set>
                            <displayer>FT::NO_FILL_IN</displayer>
                            <target_url>http://link.springer.com/book/10.1007/978-1-4614-3612-6/page/1</target_url>
                            <is_related>no</is_related>
                            <coverage>
                             <coverage_text>
                              <threshold_text></threshold_text>
                              <embargo_text></embargo_text>
                             </coverage_text>
                            </coverage>
                           </target>
                        </ctx_obj_targets>
                      </ctx_obj>
                    </ctx_obj_set>'
                    
    @sfx_no_response = '<ctx_obj_set>
                          <ctx_obj identifier="">
                           <ctx_obj_attributes></ctx_obj_attributes>
                           <ctx_obj_targets></ctx_obj_targets>
                          </ctx_obj>
                        </ctx_obj_set>'
  end
  
  # -----------------------------------------------------------------------------------
  def test_validate_citation
    @service = SfxService.new(@config)
    
    # SFX needs an identifier or an author and title
    @citations.each do |citation|
      assert_equal citation.extras['valid'][0], @service.validate_citation(citation), "Was expecting #{citation.title} to #{citation.extras['valid'][0] ? 'pass' : 'fail'} the validation check because #{citation.extras['reason'][0]}!"
    end
  end
  
  # -----------------------------------------------------------------------------------
  def test_add_citation_to_target
    @service = SfxService.new(@config)
    @service.request = Cedilla::Request.new({:requestor_ip => '127.0.0.1'})
    
    # SFX should append the ISBN to the url path
    @citations.each do |citation|
      if citation.extras['valid'][0]
        target = "#{@config['target']}?#{@config['query_string']}"
        
        title = (citation.article_title.nil? ? citation.journal_title.nil? ? citation.book_title.nil? ? citation.title.nil? ? '' : citation.title : citation.book_title : citation.journal_title : citation.article_title)
        
        response = @service.add_citation_to_target(citation)
        
        assert_equal 0, response.index(target), "Was expecting to see #{target} as the beginning of the URL for the #{citation.extras['reason'][0]} test but got #{response}!"
        assert response.include?(URI.escape(title)), "Was expecting to see #{URI.escape(title)} as the beginning of the URL for the #{citation.extras['reason'][0]} test but got #{response}!"
      end
    end
  end
  
  # -----------------------------------------------------------------------------------
  def test_process_response
    # SFX should append the ISBN to the url path
    @citations.each do |citation|
      @service = SfxService.new(@config)
      @service.request = Cedilla::Request.new({:requestor_ip => '127.0.0.1'})
      
      # Setup the stub response
      @service.response_status = 200
      @service.response_headers = {'Content-Type' => 'application/xml'}
      @service.response_body = (citation.extras['valid'][0] ? @sfx_response : @sfx_no_response)
      
      # Add the citation to the target to setup the return url and then call process_response
      @service.add_citation_to_target(citation)
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
class SfxService
  def request=(val)
    @request = val
  end
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