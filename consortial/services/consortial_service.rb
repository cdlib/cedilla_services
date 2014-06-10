require 'nokogiri'

class ConsortialService < CedillaService

  # -------------------------------------------------------------------------
  # All implementations of CedillaService should load their own config and pass
  # it along to the base class
  # -------------------------------------------------------------------------
  def initialize
    begin
      @config = YAML.load_file('./config/consortial.yaml')
    
      super(@config)
      
    rescue Exception => e
      $stdout.puts "Unable to load configuration file!"
    end
    
  end
  
  # -------------------------------------------------------------------------
  def process_request(citation, headers)
    # If the data in the local XML file is outdated OR the file doesn't exist
    if File.exists?(@config['xml_file'])
      last_updated = File.new(@config['xml_file'], "r").mtime 
    
      # If the number od days since the data was last downloaded is greater than the number of days specified in the config
      download_data if ((Time.now - last_updated).to_i / (24 * 60 * 60) > @config['max_age_days'].to_i)
    else
      download_data
    end
    
    @campus = citation.others['campus'] unless citation.others.nil?
    @ip = headers[:ip] 
    
    # Load the cross reference data from disk
    if File.exists?(@config['xml_file'])
      @response_status = 200
      @response_body = File.open(@config['xml_file'], "r").read
      @response_headers = {}
      
    else
      @response_status = 404
      @response_body = ''
      @response_headers = {}
    end
    
    # Pass it on to process_request
    process_response(@response_status, @response_headers, @response_body)
  end
  
  # -------------------------------------------------------------------------
  # Each implementation of a CedillaService MUST override this method!
  # -------------------------------------------------------------------------
  def process_response(status, headers, body)
    
    doc = Nokogiri::XML(@response_body)
    
    citation = Cedilla::Citation.new
    
    found = false
    
    doc.xpath(@config["xpath_campus_grouping"]).each do |campus|
      unless found
        if !@campus.nil?
          if @campus.to_s == campus.xpath(@config['xpath_campus_name']).to_s
            first_ip = campus.xpath(@config['xpath_ip_range_element']).first 
          
            # Always put the IP into the citation because the user may not be on their own campus (e.g student from UC Berkeley 
            # visitng UC Davis) so we should use whichever campus the send. SFX and other services will gate their access if 
            # necessary to the resources behind them
            citation.others['ip'] = first_ip.xpath(@config['xpath_ip_range_start'])
            found = true
          end
      
        else
          campus.xpath(@config['xpath_ip_range_element']).each do |range|
            if @ip.to_s >= range.xpath(@config['xpath_ip_range_start']).to_s and @ip.to_s <= range.xpath(@config['xpath_ip_range_end']).to_s              
              citation.others['campus'] = campus.xpath(@config['xpath_campus_name']) if citation.campus.nil?
              found = true 
            end
          end
        end
      end # unless found
    end
    
    citation
  end

  
private
  # -------------------------------------------------------------------------
  def download_data
    target = @config['target']
    
    # Call the target
    begin  
      unless target.nil? or target.strip == ''
        response = call_target(Cedilla::Citation.new, target, {}, 0)
      end
    
    rescue => e
      @response_status = response.code.to_i unless response.nil?
      response.header.each_header{ |key,val| @response_headers["#{key.to_s}"] = val.to_s } unless response.nil?
      @response_body = response.body.to_s unless response.nil?
      raise
    end
    
    unless response.nil?
      # Save the XML to disk
      file = File.new(@config['xml_file'], "w+")
      
      file.write(response.body.to_s)
      file.flush
      file.close
    else
      raise Exception.new("Unable to contact the target!")
    end
    
  end
  
end