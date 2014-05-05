require 'marc'

require 'cedilla/author'

class LcAuthorityService < CedillaService

  # -------------------------------------------------------------------------
  # All implementations of CedillaService should load their own config and pass
  # it along to the base class
  # -------------------------------------------------------------------------
  def initialize
    begin
      @config = YAML.load_file('./config/lookup_lc_authority.yml')
    
      super(@config)
      
    rescue Exception => e
      $stdout.puts "Unable to load configuration file!"
    end
    
  end
  
  # -------------------------------------------------------------------------
  # All CoverThing cares about is the ISBN, so overriding the base class
  # -------------------------------------------------------------------------
  def add_citation_to_target(citation)
    ret = "#{build_target}"
    
    unless citation.authors.first.nil?
      ret += "local.FamilyName = \"#{citation.authors.first.last_name.downCase}\" " unless citation.authors.first.last_name.nil?
      
      ret += "#{ret[-1] != '=' ? 'and ' : ''}local.FirstName = \"#{citation.authors.first.first_name.downCase}\" " unless citation.authors.first.fist_name.nil?
    end
    
    puts ret
    ret
  end
  
  # -------------------------------------------------------------------------
  # Each implementation of a CedillaService MUST override this method!
  # -------------------------------------------------------------------------
  def process_response(status, headers, body)
    attributes = {}
    auths = []
  
  puts body
    
  #  json = JSON.parse(body)
  
  #  puts json
   
    Cedilla::Citation.new(attributes)
    
  end
  
end