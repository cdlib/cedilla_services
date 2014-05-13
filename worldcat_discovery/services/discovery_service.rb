require 'oclc/auth'
require 'worldcat/discovery'

require 'cedilla/author'
require 'cedilla/resource'

class DiscoveryService < CedillaService

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
  def process_request(citation, headers)
    ret = {'citations' => []}
    
    if !citation.oclc.nil?
      # We have a specific item id
      bib = WorldCat::Discovery::Bib.find(citation.oclc)
      
      ret['citations'] << buildCitation(bib) unless bib.nil?
      
    else
      # We don't have an item id so do a search
      params = {:q => (citation.book_title.nil? ? 
                         citation.journal_title.nil? ? 
                           citation.article_title.nil? ? citation.title : citation.article_title : 
                         citation.journal_title : 
                       citation.book_title)}
                       
      params[:au] = citation.authors.first.last_name unless citation.authors.size <= 0
      params[:facets] = ['author:10', 'inLanguage:10']
      params[:startNum] = 0
      
      results = WorldCat::Discovery::Bib.search(params)
      
      results.bibs.map do |bib|
        new_citation = buildCitation(bib)
        
        ret['citations'].each do |citation|
          # If the new citation matches one we've already processed just combine the values onto the existing citation
          if citation == new_citation
            citation.combine(new_citation)
            new_citation = nil
          end
        end
        
        ret['citations'] << new_citation unless new_citation.nil?
      end
    end
  
    process_response(200, {}, ret)
  end
  
  # -------------------------------------------------------------------------
  # Each implementation of a CedillaService MUST override this method!
  # -------------------------------------------------------------------------
  def process_response(status, headers, body)
    LOGGER.debug "response status: #{status}"
    LOGGER.debug "response headers: #{headers.collect{ |k,v| "#{k}=#{v}" }.join(', ')}"
    LOGGER.debug "response body: #{body}"
  
    puts body
    
    body
    
=begin    
    json = JSON.parse(body)  
  
  
    json['@graph'].each do |graph|
      if graph['schema:significantLink'].nil?
        
        unless graph['schema:about'].nil?
          ret['citations'] << process_section(graph['schema:about'])
        end
        
      else
        # We got back multiple OCLC matches!
        graph['schema:significantLink'].each do |citation|
        
          if citation.is_a?(Hash)
            #process_section(citation['schema:author']) unless citation['schema:author'].nil?
        
            ret['citations'] << process_section(citation['schema:about']) unless citation['schema:about'].nil?
          end
        end 
      end       
    end
=end
    
  end
  
private
  # -------------------------------------------------------------------------
  def buildCitation(bib)
    citation = {}
    author = {}
    resource = {}

puts "id: #{bib.id}"    
puts "name: #{bib.name}"
puts "oclc: #{bib.oclc_number}"
puts "isbns: #{bib.isbns}"
puts "work_uri: #{bib.work_uri}"
puts "num_pages: #{bib.num_pages}"
puts "date_published: #{bib.date_published}"
puts "type: #{bib.type}"
puts "same_as: #{bib.same_as}"
puts "language: #{bib.language}"
puts "publisher: #{bib.publisher.collect{ |pub| "#{pub.id}" }.join(', ')}" unless bib.publisher.nil? #" : #{pub.name} - #{pub.type}" }.join(', ')}"
puts "display_position: #{bib.display_position}"
puts "book_edition: #{bib.book_edition}"
puts "subjects: #{bib.subjects.collect{ |sub| "#{sub.id}" }.join(', ')}" unless bib.subjects.nil? #: #{sub.name} - #{sub.type}" }.join(', ')}"
puts "work_examples: #{bib.work_examples.collect{ |ex| "#{ex.id}" }.join(', ')}" unless bib.work_examples.nil? #: #{ex.name} (isbn: #{ex.isbn}) - #{ex.type}" }.join(', ')}"
puts "places_of_publication: #{bib.places_of_publication.collect{ |place| "#{place.id}" }.join(', ')}" unless bib.places_of_publication.nil? #: #{place.name} - #{place.type}" }.join(', ')}"
puts "descriptions: #{bib.descriptions}"
puts "reviews: #{bib.reviews.collect{ |rev| "#{rev.id}" }.join(', ')}" unless bib.reviews.nil?#: #{rev.body} - #{rev.type}" }.join(', ')}"
puts "author: #{bib.author.id}" unless bib.author.nil? #: #{per.name} - #{per.type}" }.join(', ')}"
puts "contributors: #{bib.contributors}"
    
    citation['title'] = bib.name
    citation['isbn'] = bib.isbns.last unless bib.isbns.nil?
    citation['publisher'] = bib.publisher.first.to_s unless bib.publisher.first.nil?
    citation['publication_date'] = bib.date_published unless bib.date_published.nil?
    citation['publication_place'] = bib.places_of_publication.last.id.to_s unless bib.places_of_publication.last.nil?
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
    
    ret = Cedilla::Citation.new(citation)
    ret.authors << Cedilla::Author.new(author) if author.size > 0
    ret.resources << Cedilla::Resource.new(resource) if resource.size > 0
    
    ret
  end
=begin
  def process_section(section)
    ret = nil
    citation_attributes = {}
    resource_attributes = {:source => 'worldcat'}
    authors = []
    
    section.each do |key, value|
      
      puts "looking at #{key} -> #{value}"
      
      
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
=end
  
end
