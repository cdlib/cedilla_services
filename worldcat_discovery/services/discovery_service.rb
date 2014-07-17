require 'oclc/auth'
require 'worldcat/discovery'

require 'cedilla/service'
require 'cedilla/author'
require 'cedilla/resource'

class DiscoveryService < Cedilla::Service

  # -------------------------------------------------------------------------
  # All implementations of CedillaService should load their own config and pass
  # it along to the base class
  # -------------------------------------------------------------------------
  def initialize
    begin
      @config = YAML.load_file('./config/worldcat_discovery.yaml')
    
      super(@config)
    
    rescue Exception => e
      $stdout.puts "ERROR: Unable to load configuration file!"
    end
    
    begin  
      #@auth_target = @config['auth_target']
      wskey = OCLC::Auth::WSKey.new(@config['auth_key'], @config['auth_secret'])
      WorldCat::Discovery.configure(wskey)
      
    rescue Exception => e
      $stdout.puts "ERROR: Initializing Worldcat Discovery Objects - #{e.message}"
      $stdout.puts e.backtrace
    end
    
  end

  # -------------------------------------------------------------------------
  def process_request(request, headers)
    ret = {'citations' => []}
    @graph = RDF::Graph.new
    
    if !request.citation.oclc.nil?
      # We have a specific item id
      bib = WorldCat::Discovery::Bib.find(request.citation.oclc)
      
      ret['citations'] << build_citation(bib) unless bib.nil?
      
    else
      # We don't have an item id so do a search
      params = {:q => (request.citation.book_title.nil? ? 
                       request.citation.journal_title.nil? ? 
                       request.citation.article_title.nil? ? request.citation.title : request.citation.article_title : 
                       request.citation.journal_title : 
                       request.citation.book_title)}
                       
      params[:au] = request.citation.authors.first.last_name unless request.citation.authors.size <= 0
      params[:facets] = ['author:10', 'inLanguage:10']
      params[:startNum] = 0
      
      results = WorldCat::Discovery::Bib.search(params)
      
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
  
    @response_status = 200
    @response_headers = {}
    @response_body = ret
    
    process_response
  end
  
  # -------------------------------------------------------------------------
  # Each implementation of a CedillaService MUST override this method!
  # -------------------------------------------------------------------------
  def process_response
    LOGGER.debug "response status: #{@response_status}"
    LOGGER.debug "response headers: #{@response_headers.collect{ |k,v| "#{k}=#{v}" }.join(', ')}"
    LOGGER.debug "response body: #{@response_body}"
  
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
    citation['publisher'] = bib.publisher.first.to_s unless bib.publisher.first.nil?
    citation['publication_date'] = bib.date_published unless bib.date_published.nil?
    citation['publication_place'] = bib.places_of_publication.select{ |place| !(place.subject.to_s =~ /_:[A-Z][0-9]+/) } unless bib.places_of_publication.nil?
    citation['pages'] = bib.num_pages unless bib.num_pages.nil?
    citation['edition'] = bib.book_edition unless bib.book_edition.nil?
    citation['subjects'] = bib.subjects.collect{ |sub| "#{sub.id}" } unless bib.subjects.nil?
    citation['contributors'] = bib.contributors.collect{ |con| "#{con.name} (#{con.id.to_s})" } unless bib.contributors.nil?
    
    author['authority'] = bib.author.to_s unless bib.author.nil?
    author['full_name'] = bib.author.name unless bib.author.nil?
    
    resource['target'] = bib.id.to_s
    resource['format'] = bib.type.to_s 
    resource['description'] = bib.descriptions.first unless bib.descriptions.first.nil?
    resource['language'] = bib.language unless bib.language.nil?
    resource['oclc_lod'] = bib.work_uri unless bib.work_uri.nil?
    resource['reviews'] = bib.reviews.collect{ |rev| "#{rev.id}" } unless bib.reviews.nil?
    resource['rating'] = bib.display_position || 1
    
puts 'Citation: -------------------------------'
puts citation
puts 'Author: -------------------------------'
puts author

    
    ret = Cedilla::Citation.new(citation)
    ret.authors << Cedilla::Author.new(author) if author.size > 0
    ret.resources << Cedilla::Resource.new(resource) if resource.size > 0

=begin    
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
