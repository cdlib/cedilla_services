require 'cedilla/service'

# -------------------------------------------------------------------------
# An Implementation of the CedillaService Gem
#
# Would likely sit in another file within the project
# -------------------------------------------------------------------------
class Mock1Service < Cedilla::Service
 
  # -------------------------------------------------------------------------
  # Each implementation of a CedillaService MUST override this method!
  # -------------------------------------------------------------------------
  def process_response    
    LOGGER.debug "MOCK 1 - Response from target: #{@response_status}"
    LOGGER.debug "MOCK 1 - Body:"
    LOGGER.debug @response_body
    
    Cedilla::Citation.new({:publisher => 'Well known publishing house',
                           :publication_place => 'London',
                           :authors => [{:last_name => 'Dickens', :first_name => 'Charles'}]})
  end


  # --------------------------------------------------------------------------------
  def process_request(request, headers)
    @response_status = 200
    @response_headers = {}
    @response_body = "This is sample data sent back from our fake endpoint."

    self.process_response
  end
  
end
