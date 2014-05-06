require 'cedilla'
require 'cedilla/error'
require './services/cover_thing_service.rb'

class CoverThing < Sinatra::Application
  
  default = "The Cover Thing service is expecting an HTTP POST with a JSON message similar to the examples found on: " +
            "<a href='https://github.com/cdlib/cedilla_delivery_aggregator/wiki/JSON-Data-Model:-Between-Aggregator-and-Services'>" +
            "Cedilla Delivery Aggregator Wiki</a>"
  
  # -------------------------------------------------------------------------
  get '/cover_thing' do
    default
  end
  
  # -------------------------------------------------------------------------
  post '/cover_thing' do
    headers['Content-Type'] = 'text/json'
    payload = ""
    service = CoverThingService.new
    
    request.body.rewind  # Just a safety in case its already been read
    
    begin  
      data = request.body.read
      
      id = JSON.parse(data)['id']
      
      LOGGER.info "Received request for id: #{id}"
      LOGGER.debug data 
      
      citation = Cedilla::Translator.from_cedilla_json(data)
      
      begin
        if citation.isbn.nil? and citation.eisbn.nil?
          # No ISBN was passed, which this service requires so just send back a 404 Not Found
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
   
end



