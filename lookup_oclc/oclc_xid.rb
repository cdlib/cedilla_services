require 'cedilla'
require 'cedilla/error'

require('./services/xid_service.rb')

class OclcXid < Sinatra::Application

  default = "The OCLC Xid service is expecting an HTTP POST with a JSON message similar to the examples found: " +
            "https://github.com/cdlib/cedilla_delivery_aggregator/wiki/JSON-Data-Model:-Between-Aggregator-and-Services"
  
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
      
      citation = Cedilla::Translator.from_cedilla_json(data)
      
      begin
        if citation.isbn.nil? and citation.eisbn.nil? and citation.issn.nil? and citation.eissn.nil?
          # No ISBN or ISSN was passed, which this service requires so just send back a 404 Not Found
          status 404  
          payload = Cedilla::Translator.to_cedilla_json(id, Cedilla::Citation.new({}))
          
        else
          new_citation = service.process_request(citation, {})
          
          if new_citation.is_a?(Cedilla::Citation)
            payload = Cedilla::Translator.to_cedilla_json(id, new_citation)
          
          else
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
          puts e.message
          puts e.backtrace
          payload = Cedilla::Translator.to_cedilla_json(id, Cedilla::Error.new(Cedilla::Error.LEVELS[:error], "An error occurred while processing the request."))
        end
      end
      
    rescue Exception => e
      # JSON parse exception should throw an invalid request!
      puts e.message
      puts e.backtrace
      status 400
    end
    
    payload
    
  end

end
