require 'nokogiri'
require 'cedilla/author'
require 'cedilla/service'

class SfxService < Cedilla::Service

  # -------------------------------------------------------------------------
  def validate_citation(citation)
    ret = false
    
    # If the citation has an identifier OR it has a title for its respective genre then its valid
    if citation.is_a?(Cedilla::Citation)
      ret = citation.has_identifier? 
      
      if !ret and ['book', 'bookitem'].include?(citation.genre) 
        ret = (!citation.authors.empty? and (!citation.title.nil? or !citation.book_title.nil?))

      elsif !ret and ['journal', 'issue', 'series'].include?(citation.genre)
        ret = (!citation.authors.empty? and (!citation.title.nil? or !citation.journal_title.nil?))
        
      elsif !ret and ['article', 'report', 'paper', 'dissertation'].include?(citation.genre)
        ret = (!citation.authors.empty? and (!citation.title.nil? or !citation.article_title.nil?))
      end
    end
    
    LOGGER.debug "SFX - Checking validity of Citation (must have an Identifier or a Title and Author) -> #{ret}"
    
    ret
  end
  
  # -------------------------------------------------------------------------
  def add_citation_to_target(citation)
    target = "#{build_target}"
    target += '&' unless target[-1] == '&' or target[-1] == '?'

    target += URI.escape("rfr_id=info:sid/#{@config['sid_identifier'] || 'CEDILLA'}")
    target += "&#{@config['campus_affiliation_parameter']}=#{@request.requestor_ip}" unless @request.requestor_ip.nil?
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

    LOGGER.debug "SFX - calling: #{target}"

    target
  end
  
  # -------------------------------------------------------------------------
  # Each implementation of a CedillaService MUST override this method!
  # -------------------------------------------------------------------------
  def process_response()
    
    LOGGER.debug "SFX - Response from target: #{@response_status}"
    #LOGGER.debug "SFX - Headers: #{@response_headers.collect{ |k,v| "#{k} = #{v}" }.join(', ')}"
    #LOGGER.debug "SFX - Body:"
    #LOGGER.debug @response_body
    
    begin
      doc = Nokogiri::XML(@response_body)
    
      citation = Cedilla::Citation.new({})
  
      doc.xpath("//ctx_obj_set//ctx_obj_targets//target").each do |target|
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

        citation.resources << resource unless citation.has_resource?(resource) or resource.nil?
      
      end
    
    rescue Exception => e
      LOGGER.error("SFX - error: #{e.message}")
      LOGGER.error(e.backtrace)
      
      raise Cedilla::Error.new('fatal', 'Unable to process the XML response from SFX!')
    end
    
    citation
    
  end
  
end