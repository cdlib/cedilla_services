require 'cedilla/service'

# -------------------------------------------------------------------------
# An Implementation of the CedillaService Gem
#
# Would likely sit in another file within the project
# -------------------------------------------------------------------------
class CoverThingService < Cedilla::Service
 
  # -------------------------------------------------------------------------
  def validate_citation(citation)
    ret = false
    
    # If the citation has an identifier OR it has a title for its respective genre then its valid
    if citation.is_a?(Cedilla::Citation)
      ret = (!citation.isbn.nil? or !citation.eisbn.nil?)
    end
    
    LOGGER.debug "COVER THING - Checking validity of Citation (must have ISBN) -> #{ret}"
    
    ret
  end
  
  # -------------------------------------------------------------------------
  # All CoverThing cares about is the ISBN, so overriding the base class
  # -------------------------------------------------------------------------
  def add_citation_to_target(citation)
    isbn = citation.isbn.nil? ? citation.eisbn : citation.isbn 
    
    unless isbn.nil?
      @ct_target = "#{build_target}#{isbn.gsub(/[^\d]/, '')}"
    end
    
    LOGGER.debug "COVER THING - Target after add_citation_to_target: #{@ct_target}"
    
    @ct_target
  end
  
  # -------------------------------------------------------------------------
  # Each implementation of a CedillaService MUST override this method!
  # -------------------------------------------------------------------------
  def process_response    
    LOGGER.debug "COVER THING - Response from target: #{@response_status}"
    #LOGGER.debug "COVER THING - Headers: #{@response_headers.collect{ |k,v| "#{k} = #{v}" }.join(', ')}"
    #LOGGER.debug "COVER THING - Body:"
    #LOGGER.debug @response_body
    
    # If a content length of 43 was returned then we got the default Not-Found page!
    if @response_headers['content-length'] == '43' or @response_headers['content-length'].nil?
      return Cedilla::Citation.new({}) 
    else
      return Cedilla::Citation.new({:sample_cover_image => @ct_target}) 
    end
  end
  
end
