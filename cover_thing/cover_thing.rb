require 'cedilla'
require 'cedilla/error'
require './services/cover_thing_service.rb'

class CoverThing < Sinatra::Application
  
  validation_method = Proc.new do |citation|
    (!citation.isbn.nil? or !citation.eisbn.nil?)
  end
  
  # -------------------------------------------------------------------------
  get '/cover_thing' do
    "The Cover Thing service is expecting an HTTP POST with a JSON message similar to the examples found on: " +
    "<a href='https://github.com/cdlib/cedilla_delivery_aggregator/wiki/JSON-Data-Model:-Between-Aggregator-and-Services'>" +
    "Cedilla Delivery Aggregator Wiki</a>"
  end
  
  # -------------------------------------------------------------------------
  post '/cover_thing' do
    cedilla = CedillaController.new
    
    resp = cedilla.handle_request(request, response, CoverThingService.new, validation_method)
    
    status resp.status
    resp.body
  end
   
end



