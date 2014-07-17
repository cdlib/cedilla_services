require 'cedilla'
require 'cedilla/error'

require('./services/xid_service.rb')

class OclcXid < Sinatra::Application

  validation_method = Proc.new do |citation|
    (!citation.isbn.nil? or !citation.eisbn.nil? or !citation.issn.nil? or !citation.eissn.nil?)
  end
  
  # -------------------------------------------------------------------------
  get '/xid' do
    "The Oclc Xid service is expecting an HTTP POST with a JSON message similar to the examples found on: " +
    "<a href='https://github.com/cdlib/cedilla_delivery_aggregator/wiki/JSON-Data-Model:-Between-Aggregator-and-Services'>" +
    "Cedilla Delivery Aggregator Wiki</a>"
  end
  
  # -------------------------------------------------------------------------
  post '/xid' do
    cedilla = CedillaController.new
    
    resp = cedilla.handle_request(request, response, XidService.new, validation_method)
    
    status resp.status
    resp.body
  end

end
