require 'cedilla/service'
require 'multi_json'

# -------------------------------------------------------------------------
# An Implementation of the CedillaService Gem
#
# Would likely sit in another file within the project
# -------------------------------------------------------------------------
class InternetArchiveService < Cedilla::Service

  # -------------------------------------------------------------------------
  # All implementations of CedillaService should load their own config and pass
  # it along to the base class
  # -------------------------------------------------------------------------
  def initialize
    begin
      config = YAML.load_file('./config/internet_archive.yml')
    
      super(config)
      
    rescue Exception => e
      $stdout.puts "Unable to load configuration file!"
    end
    
  end
  
  # -------------------------------------------------------------------------
  def validate_citation(citation)
    ret = false
    # If the citation has an identifier OR it has a title for its respective genre then its valid
    if citation.is_a?(Cedilla::Citation)
      ret = (['book', 'bookitem'].include?(citation.genre) and (!citation.title.nil? or !citation.book_title.nil? or !citation.chapter_title.nil?)) or
              (['journal', 'issue', 'series'].include?(citation.genre) and (!citation.title.nil? or !citation.journal_title.nil?)) or
              (['article', 'report', 'paper', 'dissertation'].include?(citation.genre) and (!citation.title.nil? or !citation.article_title.nil?))
    end
    
    ret
  end
  
  # -------------------------------------------------------------------------
  def process_response
    new_citation = Cedilla::Citation.new
    
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
          new_citation.authors << Cedilla::Author.from_abritrary_string(CGI.escapeHTML(result['creator'].to_s)) unless result['creator'].nil?          
        end 
        
      end # results.each
    rescue Exception => e
      LOGGER.error e.message
      LOGGER.error e.backtrace
    end
    
    new_citation
    
  end

# -----------------------------------------------------------------------------
  def add_citation_to_target(citation)
    target = "#{build_target}"

    title = citation.book_title.nil? ? URI.escape(citation.title) : URI.escape(citation.book_title)
    
    author = URI.escape(citation.authors.first.last_name.chomp(','))

    target += "&#{@config['citation_uri'].sub('?', title).sub('?', author)}"
    
    target
  end
  
end