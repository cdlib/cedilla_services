require 'cedilla/service'
require 'cedilla/author'

class OclcXidService < Cedilla::Service

  # -------------------------------------------------------------------------
  def validate_citation(citation)
    # If the citation has an ISBN or ISSN
    if citation.is_a?(Cedilla::Citation)
      return (!citation.isbn.nil? or !citation.eisbn.nil? or !citation.issn.nil? or !citation.eissn.nil?)
    else
      return false
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
    
    LOGGER.debug "OCLC XID - Response from target:"
    LOGGER.debug "OCLC XID - Headers: #{@response_headers.collect{ |k,v| "#{k} = #{v}" }.join(', ')}"
    LOGGER.debug "OCLC XID - Body:"
    LOGGER.debug @response_body

    json = JSON.parse(@response_body)
  
    unless json['stat'].nil?
      if json['stat'] == 'ok'
        
        if json['group'].nil?
          # Item level found
          json['list'].each do |item|
            attributes = attributes.merge(handle_item(item))
          end
          
          attributes['authors'] = auths
          
        else
          # Joural level found so process items in the group
          json['group'].each do |group|
            group['list'].each do |item|
              attributes = attributes.merge(handle_item(item))
            end
          end
          
        end
        
      end
    end

    Cedilla::Citation.new(attributes)
    
  end
  
private
# -----------------------------------------------------------------
  def handle_item(item)
    attributes = {}
    auths = []
    
    item.each do |key,val|
      # Just take the first entry if there are multiples
      val = val.first if val.is_a?(Array)
    
      if key == 'lang'
        attributes['language'] = val
    
      elsif key == 'city'
        attributes['publication_place'] = val
      
      elsif key == 'author'
        auths << Cedilla::Author.from_arbitrary_string(val.sub('by ', ''))
        
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
   
    attributes['authors'] = auths unless auths.empty?
   
    attributes
  end
  
end