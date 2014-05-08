require 'cedilla/author'
require 'cedilla/resource'

require 'oclc/auth'

class DiscoveryService < CedillaService

  # -------------------------------------------------------------------------
  # All implementations of CedillaService should load their own config and pass
  # it along to the base class
  # -------------------------------------------------------------------------
  def initialize
    begin
      @config = YAML.load_file('./config/worldcat_discovery.yaml')
    
      super(@config)
      
      #@auth_target = @config['auth_target']
      @wskey = OCLC::Auth::WSKey.new(@config['auth_key'], @config['auth_secret'])
      
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
    
    if citation.oclc.nil? and citation.isbn.nil? and citation.eisbn.nil? and citation.issn.nil? and
                                                  citation.eissn.nil? and citation.lccn.nil?
                                                  
      ret += "/search?q=name:#{CGI.escape(title)}"
      ret += "&au=#{citation.authors.first.last_name}" unless citation.authors.first.nil?
      
    else
      id = citation.oclc unless citation.oclc.nil?
      id = citation.eisbn unless citation.eisbn.nil?
      id = citation.isbn unless citation.isbn.nil?
      id = citation.eissn unless citation.eissn.nil?
      id = citation.issn unless citation.issn.nil?
      id = citation.lccn unless citation.lccn.nil?
      
      ret += "/data/#{CGI.escape(id)}"
    end

    LOGGER.info "calling: #{ret}"

    ret
  end
  
  # -------------------------------------------------------------------------
  def process_request(citation, headers)
    # Add on the Worldcat WSKey and tell them we want JSON
    headers['authorization'] = @wskey.hmac_signature('GET', add_citation_to_target(citation))
    headers['accept'] = 'application/json'
    
    begin
      super(citation, headers)
      
    rescue Exception => e
      puts e
      
      if @response_status == 404
        return [Cedilla::Citation.new({})]
        
      else
        LOGGER.debug "Exception in process_request(): " + e.message
        LOGGER.debug e.backtrace
        
        raise e
      end
    end
  end
  
  # -------------------------------------------------------------------------
  # Each implementation of a CedillaService MUST override this method!
  # -------------------------------------------------------------------------
  def process_response(status, headers, body)
    ret = {'citations' => []}
    attributes = {}
    
    LOGGER.debug "response status: #{status}"
    LOGGER.debug "response headers: #{headers.collect{ |k,v| "#{k}=#{v}" }.join(', ')}"
    LOGGER.debug "response body: #{body}"
    
    json = JSON.parse(body)  
  
    json['@graph'].each do |graph|
      graph['schema:significantLink'].each do |citation|
        
        if citation.is_a?(Hash)
          process_section(citation['schema:author']) unless citation['schema:author'].nil?
        
          ret['citations'] << process_section(citation['schema:about']) unless citation['schema:about'].nil?
        end
      end        
    end
    
    ret
  end
  
private
  # -------------------------------------------------------------------------
  def process_section(section)
    ret = nil
    citation_attributes = {}
    resource_attributes = {:source => 'worldcat'}
    authors = []
    
    section.each do |key, value|
      
      if key == '@id'
        resource_attributes[:local_id] = value
      
      elsif key == '@type'
        resource_attributes[:format] = value
        
      elsif key.include?('displayPosition')
        resource_attributes[:rating] = value['@value'] if value.is_a?(Hash)
        
      elsif key == 'schema:numberOfPages'
        citation_attributes[:pages] = value
        
      elsif key.include?('oclcnum')
        citation_attributes[:oclc] = value['@value'] if value.is_a?(Hash)
        
      elsif key.include?('placeOfPublication')
        citation_attributes[:publication_place] = value['schema:name'] if value.is_a?(Hash)
        
      elsif key == 'schema:author'
        authors << process_author(value)
        
      elsif key == 'schema:bookEdition'
        citation_attributes[:edition] = value
        
      elsif key == 'schema:copyrightYear'
        resource_attributes[:license] = "Copyright year: #{value}"
        
      elsif key == 'schema:bookFormat'
        resource_attributes[:type] = value['@id'] if value.is_a?(Hash)
        
      elsif key == 'schema:publisher'
        citation_attributes[:publisher] = value['schema:name'] if value.is_a?(Hash)
        
      elsif key == 'schema:datePublished'
        citation_attributes[:publication_date] = value 
        
      elsif key == 'schema:about'
        citation_attributes[:subject] = process_subjects(value)
        
      elsif key == 'schema:inLanguage'
        resource_attributes[:language] = value
        
      elsif key == 'schema:name'
        citation_attributes[:title] = value
        resource_attributes[:local_title] = value
        
      elsif key == 'schema:url'
        resource_attributes[:target] = value.is_a?(Hash) ? value['@id'] : value
        
      elsif key == 'schema:description'
        resource_attributes[:description] = value
        
      elsif key.include?('sameAs')
        (citation_attributes[:sameAs] = value['@id'] unless value['@id'].nil?) if value.is_a?(Hash)
        
      elsif key == 'schema:contributor'
        contributor = process_author(value)
        unless contributor.nil?
          resource_attributes[:contributor] = contributor.full_name unless contributor.full_name.nil?
        end
        
      elsif key == 'schema:exampleOfWork'
        (citation_attributes[:linked_data] = value['@id'] unless value['@id'].nil?) if value.is_a?(Hash)
        
      elsif key == 'schema:workExample'
        (citation_attributes[:isbn] = value['schema:isbn'] unless value['schema:isbn'].nil?) if value.is_a?(Hash)
        (citation_attributes[:issn] = value['schema:issn'] unless value['schema:issn'].nil?) if value.is_a?(Hash)
        
      else
        LOGGER.debug "unmapped item ::::::: #{key} => #{value}"
      end
      
    end
    
    ret = Cedilla::Citation.new(citation_attributes)
    
    ret.resources << Cedilla::Resource.new(resource_attributes)
    
    authors.each do |auth|
      ret.authors << auth unless auth.nil?
    end
    
    ret
  end
  
  # -------------------------------------------------------------------------
  def process_author(hash)
    ret = nil
    
    if hash.is_a?(Hash)
      ret = Cedilla::Author.from_abritrary_string(hash['schema:name'].is_a?(Array) ? hash['schema:name'].last : hash['schema:name']) unless hash['schema:name'].nil?
      ret.authority = (hash['schema:sameAs']['@id'] unless hash['schema:sameAs']['@id'].nil?) unless hash['schema:sameAs'].nil?
    end
    
    ret
  end
  
  # -------------------------------------------------------------------------
  def process_subjects(array)
    ret = []
    
    array.each do |item|
      if item.is_a?(Hash)
        (ret << item['schema:name'] unless ret.include?(item['schema:name'])) unless item['schema:name'].nil?
      end
    end
    
    ret
  end
  
  
end
