Dir[File.dirname(__FILE__) + "/services/*.rb"].each{ |file| puts file; require file }

class CedillaServices < Sinatra::Application
  
  default_msg = "The ? service is expecting an HTTP POST with a JSON message similar to the examples found on: " +
    "<a href='https://github.com/cdlib/cedilla_delivery_aggregator/wiki/JSON-Data-Model:-Between-Aggregator-and-Services'>" +
    "Cedilla Delivery Aggregator Wiki</a>"
  
  # -------------------------------------------------------------------------
  get '/sfx' do default_msg.sub('?', 'ExLibris SFX') end
  # -------------------------------------------------------------------------
  post '/sfx' do
    cedilla = CedillaController.new
    resp = cedilla.handle_request(request, response, SfxService.new)
    
    status resp.status
    resp.body
  end
  
  # -------------------------------------------------------------------------
  get '/worldcat_discovery' do default_msg.sub('?', 'Worldcat Discovery') end
  # -------------------------------------------------------------------------
  post '/worldcat_discovery' do
    cedilla = CedillaController.new
    resp = cedilla.handle_request(request, response, WorldcatDiscoveryService.new)
    
    status resp.status
    resp.body
  end
  
  # -------------------------------------------------------------------------
  get '/xid' do default_msg.sub('?', 'OCLC Xid') end
  # -------------------------------------------------------------------------
  post '/xid' do
    cedilla = CedillaController.new  
    resp = cedilla.handle_request(request, response, OclcXidService.new)
    
    status resp.status
    resp.body
  end
  
  # -------------------------------------------------------------------------
  get '/internet_archive' do default_msg.sub('?', 'Internet Archive') end
  # -------------------------------------------------------------------------
  post '/internet_archive' do
    cedilla = CedillaController.new
    resp = cedilla.handle_request(request, response, InternetArchiveService.new)
    
    status resp.status
    resp.body
  end
  
  # -------------------------------------------------------------------------
  get '/cover_thing' do default_msg.sub('?', 'CoverThing') end
  # -------------------------------------------------------------------------
  post '/cover_thing' do
    cedilla = CedillaController.new
    resp = cedilla.handle_request(request, response, CoverThingService.new)
    
    status resp.status
    resp.body
  end
end
