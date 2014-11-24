require 'oclc/auth'
require 'worldcat/discovery'

require 'cedilla/service'
require 'cedilla/author'
require 'cedilla/resource'

class WorldcatDiscoveryService < Cedilla::Service

  # -------------------------------------------------------------------------
  # All implementations of CedillaService should load their own config and pass
  # it along to the base class
  # -------------------------------------------------------------------------
  def initialize(config)    
    super(config)

    begin  
      # Setup the authentication WSKey for OCLC
      wskey = OCLC::Auth::WSKey.new(@config['auth_key'], @config['auth_secret'], :services => ['WorldCatDiscoveryAPI'])
      
      WorldCat::Discovery.configure(wskey, @config['auth_institution'], @config['auth_institution'])
      
    rescue Exception => e
      $stdout.puts "ERROR: Initializing Worldcat Discovery Objects - #{e.message}"
      $stdout.puts e.backtrace
    end
    
  end
  
  # -------------------------------------------------------------------------
  def validate_citation(citation)
    ret = false
    # If the citation has an ISBN, ISSN, OCLC, or LCCN identifier OR an author and title
    if citation.is_a?(Cedilla::Citation)
      ret = (!citation.isbn.nil? or !citation.eisbn.nil? or 
              !citation.issn.nil? or !citation.eissn.nil? or 
              !citation.oclc.nil? or !citation.lccn.nil? or
              (!citation.authors.empty? and (!citation.title.nil? or !citation.book_title.nil? or
                                             !citation.journal_title.nil? or !citation.article_title.nil?)))
    end
    
    LOGGER.debug "WORLDCAT DISCOVERY - Checking validity of Citation (must have ISBN, ISSN, OCLC, LCCN, or Author and Title) -> #{ret}"
    
    ret
  end

  # -------------------------------------------------------------------------
  def process_request(request, headers)
    ret = {'citations' => []}
    @graph = RDF::Graph.new
    
    if !request.citation.oclc.nil?
      # We have a specific item id
      begin
        bib = WorldCat::Discovery::Bib.find(request.citation.oclc)
      
      rescue Exception => e
        LOGGER.debug "Failure in Worldcat::Discovery::Bib.find(#{request.citation.oclc}) module! #{e.message}"
        LOGGER.debug e.backtrace
        
        Cedilla::Error.new('fatal', "An error occurred while interacting with te Worldcat Discovery API!")
      end
      
      ret = build_citation(bib) unless bib.nil?
      
    else
      # We don't have an item id so do a search
      params = {:q => (request.citation.isbn.nil? ?
                       request.citation.eisbn.nil? ?
                       request.citation.issn.nil? ?
                       request.citation.eissn.nil? ?
                       request.citation.lccn.nil? ?
                       request.citation.doi.nil? ? 
                       request.citation.book_title.nil? ? 
                       request.citation.article_title.nil? ? 
                       request.citation.journal_title.nil? ? request.citation.title : request.citation.journal_title : 
                       request.citation.article_title : 
                       request.citation.book_title : 
                       request.citation.doi :
                       request.citation.lccn :
                       request.citation.eissn :
                       request.citation.issn :
                       request.citation.eisbn :
                       request.citation.isbn)}
                       
      params[:au] = request.citation.authors.first.last_name unless request.citation.authors.size <= 0
      params[:facets] = ['author:10', 'inLanguage:10']
      params[:startNum] = 0
      
      begin
        results = WorldCat::Discovery::Bib.search(params)
      
      rescue Exception => e
        LOGGER.debug "Failure in Worldcat::Discovery::Bib.search(#{params}) module! #{e.message}"
        LOGGER.debug e.backtrace
        
        Cedilla::Error.new('fatal', "An error occurred while interacting with te Worldcat Discovery API!")
      end
      
      if results
        results.bibs.map do |bib|
          new_citation = build_citation(bib)
        
          ret['citations'].each do |citation|
            # If the new citation matches one we've already processed just combine the values onto the existing citation
            if request.citation == new_citation
              request.citation.combine(new_citation)
              new_citation = nil
            end
          end
        
          ret['citations'] << new_citation unless new_citation.nil?
        end
        
      end
    end
  
    @response_status = 200
    @response_headers = {}
    @response_body = ret
    
    process_response
  end
  
  # -------------------------------------------------------------------------
  # Each implementation of a CedillaService MUST override this method!
  # -------------------------------------------------------------------------
  def process_response
    LOGGER.debug "WORLDCAT DISCOVERY - Response from target: #{@response_status}"
    #LOGGER.debug "WORLDCAT DISCOVERY - Headers: #{@response_headers.collect{ |k,v| "#{k} = #{v}" }.join(', ')}"
    #LOGGER.debug "WORLDCAT DISCOVERY - Body: uncomment line!"
    LOGGER.debug @response_body
  
    @response_body
  end
  
private
  # -------------------------------------------------------------------------
  def build_citation(bib)
    citation = {}
    author = {}
    resource = {}
    
    citation['title'] = bib.name
    citation['isbn'] = bib.isbns.last unless bib.isbns.nil?
    citation['publisher'] = bib.publisher.name unless bib.publisher.nil?
    citation['publication_date'] = bib.date_published unless bib.date_published.nil?
    citation['publication_place'] = bib.places_of_publication.first.name unless bib.places_of_publication.nil? #{ |place| !(place.subject.to_s =~ /_:[A-Z][0-9]+/) } unless bib.places_of_publication.nil?
    citation['pages'] = bib.num_pages unless bib.num_pages.nil?
    citation['edition'] = bib.book_edition unless bib.book_edition.nil?
    citation['subjects'] = bib.subjects.collect{ |sub| "#{sub.name}" } unless bib.subjects.nil?
#    citation['contributors'] = bib.contributors.collect{ |con| "#{con.name} (#{con.id.to_s})" } unless bib.contributors.nil?
    
#    author['authority'] = bib.author.to_s unless bib.author.nil?
#    author['full_name'] = bib.author.name unless bib.author.nil?
    
    citation['target'] = bib.id.to_s
    citation['format'] = bib.type.to_s 
    citation['description'] = bib.descriptions.first unless bib.descriptions.first.nil?
    citation['language'] = bib.language unless bib.language.nil?
    citation['oclc_lod'] = bib.work_uri unless bib.work_uri.nil?
    citation['reviews'] = bib.reviews.collect{ |rev| "#{rev.id}" } unless bib.reviews.nil?
    citation['rating'] = bib.display_position || 1
    
    ret = Cedilla::Citation.new(citation)
#    ret.authors << Cedilla::Author.new(author) if author.size > 0

    unless bib.author.nil?
      ret.authors << Cedilla::Author.new({:full_name => [bib.author.given_name, bib.author.family_name].compact.join(" "),
                                          :first_name => bib.author.given_name,
                                          :last_name => bib.author.family_name,
                                          :dates => "#{bib.author.birth_date} - #{bib.author.death_date}",
                                          :type => bib.author.type})
    end

    bib.contributors.each do |con|
      ret.authors << Cedilla::Author.new({:full_name => con.name,
                                          :first_name => con.given_name,
                                          :last_name => con.family_name,
                                          :dates => "#{con.birth_date} - #{con.death_date}",
                                          :type => con.type.to_s})
    end

    ret.resources << Cedilla::Resource.new(resource) if resource.size > 0

=begin    
    # Future dev: use RDF connections to extract data from external resources like VIAAF
    load_rdf(bib.id.to_s)
    
    author_uri = @graph.query(:subject => bib.id, :predicate => RDF::URI.new('http://schema.org/author')).first.object
    puts author_uri.to_s
    load_rdf(author_uri.to_s)
 
    puts @graph.dump(:ttl)
    puts "\n\n"
=end
        
    ret
  end

  # For future development if we choose to follow out the RDF LOD
  # -------------------------------------------------------------------------
  def load_rdf(url)
    data = RestClient.get(url, :accept => 'application/rdf+xml')
    
    RDF::Reader.for(:rdfxml).new(data) do |reader|
      reader.each_statement{ |statement| @graph << statement }
    end
  end
  
end
