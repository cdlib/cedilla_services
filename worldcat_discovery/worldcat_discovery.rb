require('./services/discovery_service.rb')

class WorldcatDiscovery < Sinatra::Application
  
  post '/worldcat_discovery' do
    200
    headers['Content-Type'] = 'text/json'
     
    request.body.rewind  # Just a safety in case its already been read
  
    service = WorldcatDiscoveryService.new
  
    translator = Cedilla::Translator.new
  
    json = JSON.parse(request.body.read)    
    citation = Cedilla::Citation.new(json['citation']) unless json['citation'].nil?
  
    begin
      new_citations = service.process_request(citation, {})
      
      # Build the JSON will be handled by the gem eventually
      out = "\"citations\":["
  
      new_citations.each do |new_citation|
        out += out[-1] == '}' ? ",{" : "{"
      
        new_citation.to_hash.each do |key, value|
          out += "\"#{key}\":\"#{value}\","
        end
      
        if new_citation.authors.size > 0
          out += "\"authors\":["
          new_citation.authors.each do |auth|
            out += out[-1] == '}' ? ",{" : "{"
        
            auth.to_hash.each do |key, value|
              out += "\"#{key}\":\"#{value}\","
            end
        
            out = (out[-1] == ',') ? out[0..out.length - 2] + "}" : out + "}"
          end
          out += "],"
        end
        
        if new_citation.resources.size > 0
          out += "\"resources\":["
          new_citation.resources.each do |rsc|
            out += out[-1] == '}' ? ",{" : "{"
        
            rsc.to_hash.each do |key, value|
              out += "\"#{key}\":\"#{value}\","
            end
        
            out = (out[-1] == ',') ? out[0..out.length - 2] + "}" : out + "}"
          end
          out += "],"
        end
        
        out = (out[-1] == ',') ? out[0..out.length - 2] + "}" : out + "}"
      end
    
      out += "]"
        
    rescue Exception => e
      puts e
      puts e.backtrace
    end
    
    "{\"time\":\"#{Date.today.to_s}\",\"id\":\"#{json['id']}\",\"api_ver\":\"#{json['api_ver']}\",#{out}}"
  end

end
