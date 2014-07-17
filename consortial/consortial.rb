require 'nokogiri'

# This service provides a cross reference lookup between campus and IP address. It does not perform any validation. The subsequent information
# is then passed on to SFX and other services that are dependent on the user's physical location.

class Consortial < Sinatra::Application
  
  def initialize
    begin
      @config = YAML.load_file('./config/consortial.yaml')
  
      super(@config)
    
    rescue Exception => e
      $stdout.puts "Unable to load configuration file!"
    end
  
    super
  end
  
  # ---------------------------------------------------------------------------------
  get "/campus/:code" do
    translation = ''
    
    begin
      translation = process_request(params[:code], request.ip)
    
      if translation != 'unknown'
        status 200
      
        LOGGER.info "#{translation} received from endpoint for /campus/#{params[:campus]}"
      
      else
        LOGGER.info "Could not translate /campus/#{params[:campus]}"
        status 404
      end
        
    rescue Exception => e
      status 500
      
      LOGGER.error "Error for ip: #{request.ip} --> #{e.message}"
      LOGGER.error "#{e.backtrace}"
    end
    
    translation
  end
  
  # ---------------------------------------------------------------------------------
  get "/ip" do
    translation = ''
    
    begin
      translation = process_request(nil, request.ip)
    
      if translation != 'unknown'
        status 200
      
        LOGGER.info "#{translation} received from endpoint for /ip"
      
      else
        LOGGER.info "Could not translate /ip for #{request.ip}"
        status 404
      end
        
    rescue Exception => e
      status 500
      
      LOGGER.error "Error for ip: #{request.ip} --> #{e.message}"
      LOGGER.error "#{e.backtrace}"
    end
    
    translation
  end
  
  # ---------------------------------------------------------------------------------
  get "/ip/:ip" do
    translation = ''
    
    begin
      translation = process_request(nil, params[:ip])
    
      if translation != 'unknown'
        status 200
      
        LOGGER.info "#{translation} received from endpoint for /ip/#{params[:ip]}"
      
      else
        LOGGER.info "Could not translate /ip/#{params[:ip]}"
        status 404
      end
        
    rescue Exception => e
      status 500
      
      LOGGER.error "Error for ip: #{request.ip} --> #{e.message}"
      LOGGER.error "#{e.backtrace}"
    end
    
    translation
  end
  
  
private  
  # ---------------------------------------------------------------------------------
  def process_request(code, ip)
    data = ''
    
    # If the data in the local XML file is outdated OR the file doesn't exist
    if File.exists?(@config['xml_file'])
      last_updated = File.new(@config['xml_file'], "r").mtime 
    
      # If the number od days since the data was last downloaded is greater than the number of days specified in the config
      download_data if ((Time.now - last_updated).to_i / (24 * 60 * 60) > @config['max_age_days'].to_i)
    else
      download_data
    end

    # Load the cross reference data from disk
    if File.exists?(@config['xml_file'])
      data = File.open(@config['xml_file'], "r").read
    end
    
    ret = 'unknown'
    found = false
    
    doc = Nokogiri::XML(data)
    
    doc.xpath(@config["xpath_campus_grouping"]).each do |campus|
      unless found
        if !code.nil?
          if code.to_s == campus.xpath(@config['xpath_campus_name']).to_s
            
            # Always put the IP into the citation because the user may not be on their own campus (e.g student from UC Berkeley 
            # visitng UC Davis) so we should use whichever campus the send. SFX and other services will gate their access if 
            # necessary to the resources behind them
            first_ip = campus.xpath(@config['xpath_vpn_range_element']).first
            
            if first_ip.nil?
              first_ip = campus.xpath(@config['xpath_ip_range_element']).first if first_ip.nil?
          
              ret = first_ip.xpath(@config['xpath_ip_range_start'])
            else
              ret = first_ip.xpath(@config['xpath_vpn_range_start'])
            end
            
            found = true
          end
      
        else
          puts "looking for ip: #{ip} in #{campus}"
          
          # Check the IP Ranges
          campus.xpath(@config['xpath_ip_range_element']).each do |range|
            if ip.to_s >= range.xpath(@config['xpath_ip_range_start']).to_s and ip.to_s <= range.xpath(@config['xpath_ip_range_end']).to_s
              ret = campus.xpath(@config['xpath_campus_name']) if ret == 'unknown'
              found = true 
            end
          end
          
          # Check the VPN Ranges
          unless found
            campus.xpath(@config['xpath_vpn_range_element']).each do |range|
              if ip.to_s >= range.xpath(@config['xpath_vpn_range_start']).to_s and ip.to_s <= range.xpath(@config['xpath_vpn_range_end']).to_s
                ret = campus.xpath(@config['xpath_campus_name']) if ret == 'unknown'
                found = true 
              end
            end
          end
        end
      end # unless found
    end
    
    ret
  end

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
