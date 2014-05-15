require 'nokogiri'
require 'cedilla/author'

class SfxService < CedillaService

  # -------------------------------------------------------------------------
  # All implementations of CedillaService should load their own config and pass
  # it along to the base class
  # -------------------------------------------------------------------------
  def initialize
    begin
      @config = YAML.load_file('./config/sfx.yaml')
    
      super(@config)
      
    rescue Exception => e
      $stdout.puts "Unable to load configuration file!"
    end
    
  end
  
  # -------------------------------------------------------------------------
  # 
  # -------------------------------------------------------------------------
  def add_citation_to_target(citation)
    target = "#{build_target}"
    target += '&' unless target[-1] == '&' or target[-1] == '?'
    
    original_citation = citation.others.select{ |entry| !entry['original_citation'].nil? }.flatten
    
    if !original_citation.nil?
      target += URI.escape(original_citation.first['original_citation'].to_s)
      
      puts target
    else
      hash = citation.to_hash
      target += hash.collect{ |k,v| 
        "#{URI.escape(k.to_s)}=#{URI.escape(v.to_s)}" unless ['authors','others','short_titles'].include?(k)
      }.join('&')
    
      target += '&' unless target[-1] == '&' or target[-1] == '?'    
    
      auth = citation.authors.first
      target += auth.to_hash.collect{ |k, v| "#{URI.escape(k)}=#{URI.escape(v)}" }.join('&') unless auth.nil?

      target += citation.others.collect{ |k, v| "#{URI.escape(k)}=#{URI.escape(v.to_s)}" }.join('&')
    end
    
    target
  end
  
  # -------------------------------------------------------------------------
  # Each implementation of a CedillaService MUST override this method!
  # -------------------------------------------------------------------------
  def process_response(status, headers, body)
    
    LOGGER.debug "Response from SFX:"
    LOGGER.debug "Headers: #{headers.collect{ |k,v| "#{k} = #{v}" }.join(', ')}"
    LOGGER.debug "Body:"
    LOGGER.debug body
    
    doc = Nokogiri::XML(@response_body)
    
    citation = Cedilla::Citation.new
    
    doc.xpath("//sfx_menu//targets//target").each do |target|

      params = {}

      # Figure out what the service type is
      type = target.xpath("service_type").text.downcase.sub('get', '')
      
      if type == "abstract"   # Source of an Abstract
        # Go get the abstract and add it to the citation
#        params = {:source => target.xpath("target_public_name").text,
#                  :target => target.xpath("target_url").text,
#                  :local_id => target.xpath("target_service_id").text,
#                  :charset => target.xpath("char_set").text,
#                  :description => target.xpath("note").text,
#                  :format => 'extra',
#                  :availability => true}
        
        
      elsif ['fulltxt', 'selectedfulltxt'].include?(type)  # Full Text
        params = {:source => target.xpath("target_public_name").text,
                  :target => target.xpath("target_url").text,
                  :local_id => target.xpath("target_service_id").text,
                  :charset => target.xpath("char_set").text,
                  :description => target.xpath("note").text,
                  :format => 'electronic',
                  :availability => true}
                  
      elsif type == 'doi'  # Highlighted Link
        
      elsif type == "holding"                  # Physical item
#        params = {:source => target.xpath("target_public_name").text,
#                  :catalog_target => target.xpath("target_url").text,
#                  :local_id => target.xpath("target_service_id").text,
#                  :charset => target.xpath("char_set").text,
#                  :note => target.xpath("note").text,
#                  :format => 'print',
#                  :availability => true}
        
      elsif type == "documentdelivery"         # ILL
#        params = {:source => target.xpath("target_public_name").text,
#                  :catalog_target => target.xpath("target_url").text,
#                  :local_id => target.xpath("target_service_id").text,
#                  :charset => target.xpath("char_set").text,
#                  :note => target.xpath("note").text,
#                  :format => 'print',
#                  :availability => true}
        
      elsif type == "reference"                # Citation Export Tools
#        query = target.xpath("target_url").text
        
        #puts "Original: #{query}"
        #puts "Stripped: #{query.sub(/&openurl=.+&?/, '')}"
        
        # Remove any openurl values because they are redundant
#        query = query.sub(/&url=.+&?/, '')
#        query = query.sub(/&openurl=.+&?/, '')
        
#        hash = CedillaUtilities.query_string_to_hash(query[(query.index('?') + 1)..query.size])
        
#        citation.combine(@response_translator.hash_to_citation(hash))
        
                  
      elsif type == "citedjournal"             # Services that show where the item has been cited
#        params = {:source => target.xpath("target_public_name").text,
#                  :catalog_target => target.xpath("target_url").text,
#                  :local_id => target.xpath("target_service_id").text,
#                  :charset => target.xpath("char_set").text,
#                  :note => target.xpath("note").text,
#                  :format => 'extra',
#                  :availability => true}
                  
      elsif type == 'toc'  # Table of Contents
        
      elsif type == 'webservice'   # Webservices like 'Ask a Librarian'
        
      
      end
      
      resource = Cedilla::Resource.new(params) unless params.empty?

=begin                 
      # If the broker callback was registered and the resource is electronic
      if !resource.nil? and resource.format = 'electronic' and !@caller.nil?
        # Generate a Screen Scraper service to parse the target
        service = Cedilla::ServiceFactory.instance.create('scraper')
        service.target = resource.target.nil? ? resource.catalog_target : resource.target
        
        @logger.log(:info, "...... deferring call to the target: #{service.target}")
        
        
unless service.target.index('proquest').nil?
        # Have the broker dispatch the screen scraper service in this item's place
        caller.queue_new_service(service) unless service.target.nil?
end
        
      else
        # Otherwise add the resource to the citation
        citation.resources << resource unless citation.has_resource?(resource) or resource.nil?
      end
=end

      citation.resources << resource unless citation.has_resource?(resource) or resource.nil?
      
    end
    
    #puts citation.inspect
    
    citation
    
  end
  
end