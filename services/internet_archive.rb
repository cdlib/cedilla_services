require 'cedilla/service'
require 'multi_json'

# -------------------------------------------------------------------------
# An Implementation of the CedillaService Gem
#
# Would likely sit in another file within the project
# -------------------------------------------------------------------------
class InternetArchiveService < Cedilla::Service

  # -------------------------------------------------------------------------
  def validate_citation(citation)
    ret = false
    # If the citation has a title and an author
    if citation.is_a?(Cedilla::Citation)
      if ['book', 'bookitem'].include?(citation.genre) 
        ret = (!citation.authors.empty? and (!citation.title.nil? or !citation.book_title.nil?))

      elsif !ret and ['journal', 'issue', 'series'].include?(citation.genre)
        ret = (!citation.authors.empty? and (!citation.title.nil? or !citation.journal_title.nil?))
        
      elsif !ret and ['article', 'report', 'paper', 'dissertation'].include?(citation.genre)
        ret = (!citation.authors.empty? and (!citation.title.nil? or !citation.article_title.nil?))
      end
    end
    
    LOGGER.debug "INTERNET ARCHIVE - Checking validity of Citation (must have Title and Author) -> #{ret}"
    
    ret
  end
  
  # -------------------------------------------------------------------------
  def process_response
    new_citation = Cedilla::Citation.new({})
    
    LOGGER.debug "INTERNET ARCHIVE - Response from target: #{@response_status}"
    #LOGGER.debug "INTERNET ARCHIVE - Headers: #{@response_headers.collect{ |k,v| "#{k} = #{v}" }.join(', ')}"
    #LOGGER.debug "INTERNET ARCHIVE - Body:"
    #LOGGER.debug @response_body
    
    begin
      doc = MultiJson.load(@response_body)
      results = doc['response']['docs']
    
      results.each do |result|
        # If there is no identifier we cannot construct the target to the item!
        unless result['identifier'].nil?
          hash = {}
          
          # Some of the IA records will have the source in different spots
          hash['source'] = CGI.escapeHTML(result['contributor'].to_s)
                                                    
          # If a media_type was defined, translate it otherwise just use 'electronic'
          hash['format'] =  result['media_type'].nil? ? @config['default_media_type'] : CedillaUtilities.get_format(result['media_type']).first.to_s
                                                                                    
          # Calculate the rating if the number of reviews and a rating are present
          hash['rating'] = (result['num_reviews'].nil? or result['avg_rating'].nil?) ? @config['default_rating'] :
                                                                               result['num_reviews'].to_i * result['avg_rating'].to_f
          # Add some default values                                                                             
          hash['availability'] = @config['resource_availability']
          hash['status'] = @config['resource_status']
          hash['target'] = "#{@config['resource_target_prefix']}#{URI.escape(result['identifier'].to_s)}"
          
          # Loop throough some remaining fields and take them as-is
          ['identifier', 'title', 'language', 'description', 'license', 'year', 
                  'date', 'imagecount', 'downloads', 'publicdate'].each do |item|
                    
            hash["#{item}"] = CGI.escapeHTML(result["#{item}"].to_s) unless result["#{item}"].nil?
          end

          # Add the author and resource to the default citation object if they were found in the result
          new_citation.resources << Cedilla::Resource.new(hash) unless hash.empty?
          new_citation.authors << Cedilla::Author.from_arbitrary_string(CGI.escapeHTML(result['creator'].to_s)) unless result['creator'].nil?          
        end 
        
      end # results.each
    rescue Exception => e
      LOGGER.error "INTERNET ARCHIVE - Error: #{e.message}"
      LOGGER.error e.backtrace
    end
    
    new_citation
    
  end

# -----------------------------------------------------------------------------
  def add_citation_to_target(citation)
    target = "#{build_target}"

    title = citation.book_title.nil? ? citation.title.nil? ? '' : citation.title : citation.book_title
    
    author = citation.authors.first.nil? ? '' : citation.authors.first.last_name.chomp(',')

    target += "&#{@config['citation_uri'].sub('?', URI.escape(title)).sub('?', URI.escape(author))}"
    
    LOGGER.debug "INTERNET ARCHIVE - Calling #{target}"
    
    target
  end
  
end