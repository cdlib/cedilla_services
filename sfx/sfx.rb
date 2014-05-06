require 'cedilla/error'

require('./services/sfx_service.rb')

class Sfx < Sinatra::Application
  
  default = "The ExLibris SFX service is expecting an HTTP POST with a JSON message similar to the examples found on: " +
            "<a href='https://github.com/cdlib/cedilla_delivery_aggregator/wiki/JSON-Data-Model:-Between-Aggregator-and-Services'>" +
            "Cedilla Delivery Aggregator Wiki</a>"
  
  # -------------------------------------------------------------------------
  get '/sfx' do
    default
  end
  
  # -------------------------------------------------------------------------
  post '/sfx' do
    headers['Content-Type'] = 'text/json'
    payload = ""
    service = SfxService.new
    
    request.body.rewind  # Just a safety in case its already been read
  
    begin  
      data = request.body.read
      
      # Capture the ID passed in by the caller because we need to send it back to them
      id = JSON.parse(data)['id']
    
      LOGGER.info "Received request for id: #{id}"
      LOGGER.debug data 
      
      citation = Cedilla::Translator.from_cedilla_json(data)
      
      begin
        if !citation_valid?(citation)
          # No ISBN or ISSN was passed, which this service requires so just send back a 404 Not Found
          LOGGER.info "Request did not contain enough info to contact enpoint for id: #{id}"
          status 404  
          payload = Cedilla::Translator.to_cedilla_json(id, Cedilla::Citation.new({}))
          
        else
          new_citation = service.process_request(citation, {})
          
          if new_citation.is_a?(Cedilla::Citation)
            payload = Cedilla::Translator.to_cedilla_json(id, new_citation)
            status 200
            
            LOGGER.info "Response received from endpoint for id: #{id}"
            
          else
            LOGGER.info "Response from endpoint was empty for id: #{id}"
            status 404
            payload = Cedilla::Translator.to_cedilla_json(id, Cedilla::Citation.new({}))
          end
        end
        
      rescue Exception => e
        # Errors at this level should return a 500 level error
        status 500
        
        if e.is_a?(Cedilla::Error)
          # No logging here because the service itself should have written out to the log
          payload = Cedilla::Translator.to_cedilla_json(id, e)
        else
          LOGGER.error "Error for id: #{id} --> #{e.message}"
          LOGGER.error "#{e.backtrace}"
          payload = Cedilla::Translator.to_cedilla_json(id, Cedilla::Error.new(Cedilla::Error::LEVELS[:error], "An error occurred while processing the request."))
        end
      end
      
    rescue Exception => e
      # JSON parse exception should throw an invalid request!
      request.body.rewind
      
      LOGGER.error "Error --> #{e.message}"
      LOGGER.error "Request --> #{request.body.read}"
      LOGGER.error "#{e.backtrace}"
      status 400
    end
    
    LOGGER.debug payload
    
    payload
    
  end
  
  # ---------------------------------------------------------------------------------
  def citation_valid?(citation)
    # If the citation has an identifier OR it has a title for its respective genre then its valid
    citation.has_identifier? or 
        (['book', 'bookitem'].include?(citation.genre) and (!citation.title.nil? or !citation.book_title.nil? or !citation.chapter_title.nil?)) or
        (['journal', 'issue', 'series'].include?(citation.genre) and (!citation.title.nil? or !citation.journal_title.nil?)) or
        (['article'].include?(citation.genre) and (!citation.title.nil? or !citation.article_title.nil?))
  end
  
end
