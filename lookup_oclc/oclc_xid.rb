require 'cedilla'
require 'cedilla/error'

require('./services/xid_service.rb')

class OclcXid < Sinatra::Application

  default = "The Oclc Xid service is expecting an HTTP POST with a JSON message similar to the examples found on: " +
            "<a href='https://github.com/cdlib/cedilla_delivery_aggregator/wiki/JSON-Data-Model:-Between-Aggregator-and-Services'>" +
            "Cedilla Delivery Aggregator Wiki</a>"
  
  # -------------------------------------------------------------------------
  get '/xid' do
    default
  end
  
  # -------------------------------------------------------------------------
  post '/xid' do
    headers['Content-Type'] = 'text/json'
    payload = ""
    service = XidService.new
    
    request.body.rewind  # Just a safety in case its already been read
  
    begin  
      data = request.body.read
      
      # Capture the ID passed in by the caller because we need to send it back to them
      id = JSON.parse(data)['id']
    
      log.info "Received request for id: #{id}"
      log.debug data 
      
      citation = Cedilla::Translator.from_cedilla_json(data)
      
      begin
        if citation.isbn.nil? and citation.eisbn.nil? and citation.issn.nil? and citation.eissn.nil?
          # No ISBN or ISSN was passed, which this service requires so just send back a 404 Not Found
          log.info "Request did not contain enough info to contact enpoint for id: #{id}"
          status 404  
          payload = Cedilla::Translator.to_cedilla_json(id, Cedilla::Citation.new({}))
          
        else
          new_citation = service.process_request(citation, {})
          
          if new_citation.is_a?(Cedilla::Citation)
            payload = Cedilla::Translator.to_cedilla_json(id, new_citation)
          
            log.info "Response received from endpoint for id: #{id}"
            
          else
            log.info "Response from endpoint was empty for id: #{id}"
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
          log.error "Error for id: #{id} --> #{e.message}"
          log.error "#{e.backtrace}"
          payload = Cedilla::Translator.to_cedilla_json(id, Cedilla::Error.new(Cedilla::Error.LEVELS[:error], "An error occurred while processing the request."))
        end
      end
      
    rescue Exception => e
      # JSON parse exception should throw an invalid request!
      request.body.rewind
      
      log.error "Error --> #{e.message}"
      log.error "Request --> #{request.body.read}"
      log.error "#{e.backtrace}"
      status 400
    end
    
    log.debug payload
    
    payload
    
  end

end
