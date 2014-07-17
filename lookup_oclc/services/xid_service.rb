require 'cedilla/service'
require 'cedilla/author'

class XidService < Cedilla::Service

  # -------------------------------------------------------------------------
  # All implementations of CedillaService should load their own config and pass
  # it along to the base class
  # -------------------------------------------------------------------------
  def initialize
    begin
      @config = YAML.load_file('./config/lookup_oclc.yml')
    
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
    
    if citation.issn or citation.eissn
      ret = ret.sub('{idType}', 'xissn').sub('?', "issn/#{citation.issn.nil? ? citation.eissn : citation.issn}?")
    else
      ret = ret.sub('{idType}', 'xisbn').sub('?', "isbn/#{citation.isbn.nil? ? citation.eisbn : citation.isbn}?")
    end
    
    ret
  end
  
  # -------------------------------------------------------------------------
  # Each implementation of a CedillaService MUST override this method!
  # -------------------------------------------------------------------------
  def process_response
    attributes = {}
    auths = []
    
    json = JSON.parse(@response_body)
  
    unless json['stat'].nil?
      if json['stat'] == 'ok'
        
        json['list'].each do |item|
          item.each do |key,val|
          
            # Just take the first entry if there are multiples
            val = val.first if val.is_a?(Array)
          
            if key == 'lang'
              attributes['language'] = val
          
            elsif key == 'city'
              attributes['publication_place'] = val
            
            elsif key == 'author'
              auths << Cedilla::Author.from_abritrary_string(val.sub('by ', ''))
              
            elsif key.include?('isbn')
              attributes['isbn'] = val
              
            elsif key.include?('issn')
              attributes['issn'] = val
              
            elsif key.include?('oclc')
              attributes['oclc'] = val
              
            else
              attributes[key] = val unless key == 'url'
            end
          
          end
        end
        
        attributes['authors'] = auths
        
      end
    end
    
    Cedilla::Citation.new(attributes)
    
  end
  
end