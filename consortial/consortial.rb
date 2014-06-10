require 'cedilla/error'

require('./services/consortial_service.rb')

# This service provides a cross reference lookup between campus and IP address. It does not perform any validation. The subsequent information
# is then passed on to SFX and other services that are dependent on the user's physical location.

class Consortial < Sinatra::Application
  
  default = "The Consortial service is expecting an HTTP POST with a JSON message similar to the examples found on: " +
            "<a href='https://github.com/cdlib/cedilla_delivery_aggregator/wiki/JSON-Data-Model:-Between-Aggregator-and-Services'>" +
            "Cedilla Delivery Aggregator Wiki</a>"
  
  # -------------------------------------------------------------------------
  get '/consortial' do
    default
  end
  
  # -------------------------------------------------------------------------
  post '/consortial' do
    headers['Content-Type'] = 'text/json'
    payload = ""
    service = ConsortialService.new
    
    request.body.rewind  # Just a safety in case its already been read
  
    begin  
      data = request.body.read
      
      # Capture the ID passed in by the caller because we need to send it back to them
      id = JSON.parse(data)['id']
    
      LOGGER.info "Received request for id: #{id}"
      LOGGER.debug data 
      
      puts "#{data}\n\n"
      
      puts "citation: #{Cedilla::Translator.from_cedilla_json(data)}\n\n"
      
      citation = Cedilla::Translator.from_cedilla_json(data)
      
      begin
        if citation_valid?(citation) or !request.ip.nil?
          new_citation = service.process_request(citation, {:ip => request.ip})
          
          if new_citation.is_a?(Cedilla::Citation)
            payload = Cedilla::Translator.to_cedilla_json(id, new_citation)
            status 200
            
            LOGGER.info "Response received from endpoint for id: #{id}"
            
          else
            LOGGER.info "Response from endpoint was empty for id: #{id}"
            status 404
            payload = Cedilla::Translator.to_cedilla_json(id, Cedilla::Citation.new({}))
          end
        else
          # No ISBN or ISSN was passed, which this service requires so just send back a 404 Not Found
          LOGGER.info "Request did not contain enough info to contact enpoint for id: #{id}"
          status 404  
          payload = Cedilla::Translator.to_cedilla_json(id, Cedilla::Citation.new({}))
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
    # If the citation has a campus
    citation.others.include?('campus')
  end
  
end
