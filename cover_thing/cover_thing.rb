require 'cedilla'

class AggregatorServiceTest < Sinatra::Application
  # -------------------------------------------------------------------------
  get '/' do
    200
    "You have reached the service_test!"
  end
  
  get '/service_test' do
    "Hello World"
  end
  
  # -------------------------------------------------------------------------
  post '/service_test' do
    200
    headers['Content-Type'] = 'text/json'
       
    request.body.rewind  # Just a safety in case its already been read
    
    service = CoverThingService.new
    
    json = JSON.parse(request.body.read)    
    citation = Cedilla::Citation.new(json['citation']) unless json['citation'].nil?
    #citation = service.translator.from_cedilla_json({request.body.read)
    
    new_citation = service.process_request(citation, {})
    
    #out = service.translator.to_cedilla_json('cover_thing', new_citation)
    out = "\"citations\":[{\"cover_image\":\"#{new_citation.cover_image}\"}]"
    
    "{\"time\":\"#{Date.today.to_s}\",\"id\":\"#{json['id']}\",\"api_ver\":\"#{json['api_ver']}\"," + out + "}"
  end
   
  # -------------------------------------------------------------------------
  post '/auto_400' do
    status 400
  end
    
  # -------------------------------------------------------------------------
  post '/auto_404' do
    status 404
  end
  
  # -------------------------------------------------------------------------
  post '/auto_500_fatal' do
    status 500
    
    json = JSON.parse(request.body.read)
    
    body "{\"time\":\"#{Date.today.to_s}\",\"id\":\"#{json['id']}\",\"api_ver\":\"#{json['api_ver']}\"," +
            "\"error\":\"Something really horrible happened! :-o\",\"level\":\"fatal\"}"
  end
  
  # -------------------------------------------------------------------------
  post '/auto_500_error' do
    status 500
    
    json = JSON.parse(request.body.read)
    
    body "{\"time\":\"#{Date.today.to_s}\",\"id\":\"#{json['id']}\",\"api_ver\":\"#{json['api_ver']}\"," +
            "\"error\":\"Something quite bad happened! :-(\",\"level\":\"error\"}"
  end
  
  # -------------------------------------------------------------------------
  post '/auto_500_warning' do
    status 500
    
    json = JSON.parse(request.body.read)
    
    body "{\"time\":\"#{Date.today.to_s}\",\"id\":\"#{json['id']}\",\"api_ver\":\"#{json['api_ver']}\"," +
            "\"error\":\"Something minor happened! :-|\",\"level\":\"warning\"}"
  end
end


# -------------------------------------------------------------------------
# An Implementation of the CedillaService Gem
#
# Would likely sit in another file within the project
# -------------------------------------------------------------------------
class CoverThingService < CedillaService

  # -------------------------------------------------------------------------
  # All implementations of CedillaService should load their own config and pass
  # it along to the base class
  # -------------------------------------------------------------------------
  def initialize
    begin
      config = YAML.load_file('./config/cover_thing.yaml')
    
      super(config)
      
    rescue Exception => e
      $stdout.puts "Unable to load configuration file!"
    end
    
  end
  
  # -------------------------------------------------------------------------
  # All CoverThing cares about is the ISBN, so overriding the base class
  # -------------------------------------------------------------------------
  def add_citation_to_target(citation)
    isbn = citation.isbn.nil? ? citation.eisbn : citation.isbn
    #@ct_target = "#{build_target}#{isbn.gsub(/[^\d]/, '')}"
    @ct_target = "#{build_target}9780450027277"
    @ct_target
  end
  
  # -------------------------------------------------------------------------
  # Each implementation of a CedillaService MUST override this method!
  # -------------------------------------------------------------------------
  def process_response(status, headers, body)
    # If a content length of 43 was returned then we got the default Not-Found page!
    Cedilla::Citation.new({:cover_image => @ct_target}) unless headers['content_length'] == '43'
  end
  
end

