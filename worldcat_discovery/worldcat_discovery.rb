require 'cedilla/error'

require('./services/discovery_service.rb')

class WorldcatDiscovery < Sinatra::Application

  validation_method = Proc.new do |citation|
    (!citation.title.nil? or !citation.book_title.nil? or !citation.chapter_title.nil? or
        !citation.journal_title.nil? or !citation.article_title.nil? or !citation.isbn.nil? or
        !citation.eisbn.nil? or !citation.issn.nil? or !citation.eissn.nil? or 
        !citation.oclc.nil? or !citation.lccn.nil?)
  end
  
  # -------------------------------------------------------------------------
  get '/worldcat_discovery' do
    "The Oclc Worldcat Discovery service is expecting an HTTP POST with a JSON message similar to the examples found on: " +
    "<a href='https://github.com/cdlib/cedilla_delivery_aggregator/wiki/JSON-Data-Model:-Between-Aggregator-and-Services'>" +
    "Cedilla Delivery Aggregator Wiki</a>"
  end
  
  # -------------------------------------------------------------------------
  post '/worldcat_discovery' do
    cedilla = CedillaController.new
    
    resp = cedilla.handle_request(request, response, DiscoveryService.new, validation_method)
    
    status resp.status
    
    puts resp.body
#    Cedilla::Translator.to_cedilla_json(resp.body)
    resp.body
  end
  
end
