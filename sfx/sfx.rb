require 'cedilla/error'

require('./services/sfx_service.rb')

class Sfx < Sinatra::Application
  
  validation_method = Proc.new do |citation|
    # If the citation has an identifier OR it has a title for its respective genre then its valid
    citation.has_identifier? or 
        (['book', 'bookitem'].include?(citation.genre) and (!citation.title.nil? or !citation.book_title.nil? or !citation.chapter_title.nil?)) or
        (['journal', 'issue', 'series'].include?(citation.genre) and (!citation.title.nil? or !citation.journal_title.nil?)) or
        (['article'].include?(citation.genre) and (!citation.title.nil? or !citation.article_title.nil?))  
  end
  
  # -------------------------------------------------------------------------
  get '/sfx' do
    "The ExLibris SFX service is expecting an HTTP POST with a JSON message similar to the examples found on: " +
    "<a href='https://github.com/cdlib/cedilla_delivery_aggregator/wiki/JSON-Data-Model:-Between-Aggregator-and-Services'>" +
    "Cedilla Delivery Aggregator Wiki</a>"
  end
  
  # -------------------------------------------------------------------------
  post '/sfx' do
    cedilla = CedillaController.new
    
    resp = cedilla.handle_request(request, response, SfxService.new, validation_method)
    
    status resp.status
    resp.body
  end
  
end
