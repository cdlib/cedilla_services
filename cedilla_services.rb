require 'cedilla/error'

# require all of the services in the directory
Dir[File.dirname(__FILE__) + "/services/*.rb"].each{ |file| require file }

class CedillaServices < Sinatra::Application
  
  default_msg = "The ? service is expecting an HTTP POST with a JSON message similar to the examples found on: " +
    "<a href='https://github.com/cdlib/cedilla_delivery_aggregator/wiki/JSON-Data-Model:-Between-Aggregator-and-Services'>" +
    "Cedilla Delivery Aggregator Wiki</a>"
  
  config = YAML.load_file('./config/app.yml')

  cedilla  = CedillaController.new
  
  def CedillaServices.to_camel_case(val)
    parts = val.split('_')
    parts.collect{ |part| "#{part.capitalize}" }.join('')
  end
  
  # All services are loaded by convention. The name of the service in the YAML file MUST match the name of the ruby file and class and
  # will also become the path of to the service (e.g. a service, sfx, defined in the yaml must have a corresponding ./service/sfx.rb file
  # with the SfxService class defined and a new POST route to http://localhost:3101/sfx will be generated)
  config['services'].each do |service, defs|
    
    if defs['enabled']
      puts 'Initializing ' + service
      
      require "./services/#{service}.rb"
      
      name = "#{to_camel_case(service)}Service"
    
      # Make sure the service's class can be found
      if Object.const_defined?(name) 
        # Setup the default HTTP GET which just has a message about how to communicate with the service properly
        # -----------------------------------------------------------------------------------
        get "/#{service}" do
          default_msg.sub('?', CedillaServices.to_camel_case(service))
        end
      
        # Setup the HTTP POST for the service. The Cedilla aggregator will call this endpoint
        # -----------------------------------------------------------------------------------
        post "/#{service}" do
          begin
            klass = Object.const_get("#{CedillaServices.to_camel_case(service)}Service")

            resp = cedilla.handle_request(request, response, klass.new(defs))
      
            status resp.status
            resp.body
            
          rescue Exception => e
            # If its already a Cedilla::Error object just translate it to JSON and send it back
            if e.is_a?(Cedilla::Error)
              status (e.level == Cedilla::Error::LEVELS[:fatal] ? 500 : (e.level == Cedilla::Error::LEVELS[:error] ? 500 : 200))
              Cedilla::Translator.to_cedilla_json(params["id"], e)
              
            else
              # Otherwise it was an unhandled exception so send back a fatal error as JSON
              status 500
              Cedilla::Translator.to_cedilla_json(params["id"], Cedilla::Error.new(Cedilla::Error::LEVELS[:fatal], 
                                                                      "#{service} was unable to process the request! #{e.message}"))
            end
          end
        end
        
      else
        Logger.error("No #{name} was defined in ./service/#{service}.rb!")
      end
    end
  end
    
end
