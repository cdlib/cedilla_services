require 'cedilla'

class AggregatorServiceTest < Sinatra::Application
  # -------------------------------------------------------------------------
  get '/' do
    200
    "You have reached the service_test!"
  end
   
  # -------------------------------------------------------------------------
  post '/service_test' do
    200
    headers['Content-Type'] = 'text/html'
       
    request.body.rewind  # Just a safety in case its already been read
    
    service = CoverThingService.new
    
    citation = service.translator.from_cedilla_json(request.body.read)
    
    new_citation = service.process_request(citation, {})
    
    service.translator.to_cedilla_json('cover_thing', new_citation)
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
      config = YAML.load_file('./config/service_test.yaml')
    
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
    @ct_target = "#{build_target}#{isbn.gsub(/[^\d]/, '')}"
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

