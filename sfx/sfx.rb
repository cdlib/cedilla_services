require('./services/sfx_service.rb')

class Sfx < Sinatra::Application
  
  post '/sfx' do
    200
    headers['Content-Type'] = 'text/json'
     
    request.body.rewind  # Just a safety in case its already been read
  
    service = SfxService.new
  
    translator = Cedilla::Translator.new
  
    json = JSON.parse(request.body.read)    
    citation = Cedilla::Citation.new(json['citation']) unless json['citation'].nil?
    
    new_citation = service.process_request(citation, {})
    
    # Build the JSON will be handled by the gem eventually
    out = "\"citations\":[{"

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
    
        out = (out[-1] == ',' ? out[0..-2] + "}," : out + "},")
      end
      
      out = out[-1] == ',' ? out[0..-2] + "]," : out + "],"
    end
    
    out = out[-1] == ',' ? out[0..-2] + "}" : out + "}"
    
    out += "]"
    
    "{\"time\":\"#{Date.today.to_s}\",\"id\":\"#{json['id']}\",\"api_ver\":\"#{json['api_ver']}\"," + out + "}"
  end

end
