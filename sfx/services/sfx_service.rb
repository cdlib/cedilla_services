require 'nokogiri'
require 'cedilla/author'
require 'cedilla/service'

class SfxService < Cedilla::Service

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

    target += URI.escape("rfr_id=info:sid/#{@config['sid_identifier'] || 'CEDILLA'}")
    target += "&#{@request.original_request}"

    ver = (target.include?('Z39.88-2004') || target.include?('rft.')) ? '1_0' : '0_1'
    
    hash = citation.to_hash
    
    hash.each do |key, value|
      # Only add items that are not already included in the original citation!
      unless target.include?("#{key}=")
        translation = @config["openurl_#{ver}"][key]
      
        unless value.nil?
          # Only include items that have a translation!
          if !translation.nil?
            if translation.is_a?(Array)
              entry = "#{URI.escape(translation[0].to_s)}=#{URI.escape(translation[1].to_s.sub('?', value.to_s))}" unless value.to_s == ''
              target += "&#{entry}" unless target.include?(entry) unless entry.nil?
          
            else
              entry = "#{URI.escape(translation.to_s)}=#{URI.escape(value.to_s)}" unless value.to_s == ''
              target += "&#{entry}" unless target.include?(entry) unless entry.nil?
            end
          end
        end # unless value.nil?
        
      end #unless target.include?
    end

puts "calling: #{target}"

    target
  end
  
  
  # -------------------------------------------------------------------------
  # Each implementation of a CedillaService MUST override this method!
  # -------------------------------------------------------------------------
  def process_response()
    
    LOGGER.debug "Response from SFX:"
    LOGGER.debug "Headers: #{@response_headers.collect{ |k,v| "#{k} = #{v}" }.join(', ')}"
    LOGGER.debug "Body:"
    LOGGER.debug @response_body
    
    begin
      doc = Nokogiri::XML(@response_body)
    
      citation = Cedilla::Citation.new
    
      doc.xpath("//ctx_obj_set//ctx_obj_targets//target").each do |target|
      #doc.xpath("//sfx_menu//targets//target").each do |target|

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
    
    rescue Exception => e
      LOGGER.error(e.message)
      LOGGER.error(e.backtrace)
      
      raise Cedilla::Error.new('fatal', 'Unable to process the XML response from SFX!')
    end
    
    citation
    
  end
  
end