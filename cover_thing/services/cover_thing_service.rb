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
    @ct_target = "#{build_target}#{isbn.gsub(/[^\d]/, '')}"
    @ct_target
  end
  
  # -------------------------------------------------------------------------
  # Each implementation of a CedillaService MUST override this method!
  # -------------------------------------------------------------------------
  def process_response(status, headers, body)
    # If a content length of 43 was returned then we got the default Not-Found page!
    if headers['content_length'] == '43'
      return Cedilla::Citation.new({}) 
    else
      return Cedilla::Citation.new({:cover_image => @ct_target}) 
    end
  end
  
end
