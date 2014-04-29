class WorldcatDiscoveryService < CedillaService

  # -------------------------------------------------------------------------
  # All implementations of CedillaService should load their own config and pass
  # it along to the base class
  # -------------------------------------------------------------------------
  def initialize
    begin
      @config = YAML.load_file('./config/worldcat_discovery.yaml')
    
      super(@config)
      
      @api_key = OCLC::Auth::WSKey.new(@config['query_string']['key'], @config['query_string']['secret'])
      
    rescue Exception => e
      $stdout.puts "Unable to load configuration file!"
    end
    
  end
  
  # -------------------------------------------------------------------------
  # All CoverThing cares about is the ISBN, so overriding the base class
  # -------------------------------------------------------------------------
  def add_citation_to_target(citation)
    ret = "#{build_target}"
    
    title = citation.title unless citation.title.nil?
    title = citation.book_title unless citation.book_title.nil?
    title = citation.journal_title unless citation.journal_title.nil?
    title = citation.article_title unless citation.article_title.nil?
    
    if citation.oclc.nil?
      ret += "#{@config['target_search']}/search?q=#{CGI.escape(title)}"
    else
      ret += "#{@config['target_id']}/data/#{CGI.escape(citation.oclc)}"
    end

    ret
  end
  
  # -------------------------------------------------------------------------
  # Each implementation of a CedillaService MUST override this method!
  # -------------------------------------------------------------------------
  def process_response(status, headers, body)
  
    puts "got a - #{status}"
    
    puts "#{headers}"
    
    puts "#{body}"
  end
  
end
