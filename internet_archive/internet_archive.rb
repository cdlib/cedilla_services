require 'cedilla'
require 'cedilla/error'
require './services/internet_archive_service.rb'

class InternetArchive < Sinatra::Application
  
  validation_method = Proc.new do |citation|
    # If the citation MUST have at least a title and author!
    (['book', 'bookitem'].include?(citation.genre) and (!citation.title.nil? or !citation.book_title.nil? or !citation.chapter_title.nil?)) or
    (['journal', 'issue', 'series'].include?(citation.genre) and (!citation.title.nil? or !citation.journal_title.nil?)) or
    (['article', 'report', 'paper', 'dissertation'].include?(citation.genre) and (!citation.title.nil? or !citation.article_title.nil?))
  end
  
  # -------------------------------------------------------------------------
  get '/internet_archive' do
    "The Internet Archive service is expecting an HTTP POST with a JSON message similar to the examples found on: " +
    "<a href='https://github.com/cdlib/cedilla_delivery_aggregator/wiki/JSON-Data-Model:-Between-Aggregator-and-Services'>" +
    "Cedilla Delivery Aggregator Wiki</a>"
  end
  
  # -------------------------------------------------------------------------
  post '/internet_archive' do
    cedilla = CedillaController.new
    
    resp = cedilla.handle_request(request, response, InternetArchiveService.new, validation_method)
    
    status resp.status
    resp.body
  end
   
end



