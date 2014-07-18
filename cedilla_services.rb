require('./services/sfx.rb')
require('./services/worldcat_discovery.rb')

class CedillaServices < Sinatra::Application
  
  default_msg = "The ? service is expecting an HTTP POST with a JSON message similar to the examples found on: " +
    "<a href='https://github.com/cdlib/cedilla_delivery_aggregator/wiki/JSON-Data-Model:-Between-Aggregator-and-Services'>" +
    "Cedilla Delivery Aggregator Wiki</a>"
  
  # -------------------------------------------------------------------------
  get '/sfx'{ default_msg.sub('?', 'ExLibris SFX') }
  # -------------------------------------------------------------------------
  post '/sfx' do
    cedilla = CedillaController.new
    resp = cedilla.handle_request(request, response, SfxService.new)
    
    status resp.status
    resp.body
  end
  
  # -------------------------------------------------------------------------
  get '/worldcat_discovery'{ default_msg.sub('?', 'Worldcat Discovery') }
  # -------------------------------------------------------------------------
  post '/worldcat_discovery' do
    cedilla = CedillaController.new
    resp = cedilla.handle_request(request, response, WorldcatDiscoveryService.new)
    
    status resp.status
    resp.body
  end
  
  # -------------------------------------------------------------------------
  get '/xid' { default_msg.sub('?', 'OCLC Xid') }
  # -------------------------------------------------------------------------
  post '/xid' do
    cedilla = CedillaController.new  
    resp = cedilla.handle_request(request, response, OclcXidService.new)
    
    status resp.status
    resp.body
  end
  
  # -------------------------------------------------------------------------
  get '/internet_archive'{ default_msg.sub('?', 'Internet Archive') }
  # -------------------------------------------------------------------------
  post '/internet_archive' do
    cedilla = CedillaController.new
    resp = cedilla.handle_request(request, response, InternetArchiveService.new)
    
    status resp.status
    resp.body
  end
  
  # -------------------------------------------------------------------------
  get '/cover_thing'{ default_msg.sub('?', 'CoverThing') }
  # -------------------------------------------------------------------------
  post '/cover_thing' do
    cedilla = CedillaController.new
    resp = cedilla.handle_request(request, response, CoverThingService.new)
    
    status resp.status
    resp.body
  end
end
