require 'rubygems'
require 'bundler'
require 'sinatra'
require 'rdf/rdfxml'
require 'json/ld'
require 'equivalent-xml'
require 'oclc/auth'
require 'cedilla'

Bundler.require(:default, ENV['RACK_ENV'].to_sym)

set :environment, ENV['RACK_ENV'].to_sym
set :run, true
set :raise_errors, true

app_home = File.expand_path(File.dirname(__FILE__))
LANGUAGES = YAML::load(File.read("#{app_home}/config/languages.yml"))
FORMATS = YAML::load(File.read("#{app_home}/config/formats.yml"))


# -------------------------------------------------------------------------
require('./lib/discovery_service.rb')

run WorldcatDiscoveryService.new

# -------------------------------------------------------------------------
post '/worldcat_discovery' do
  200
  headers['Content-Type'] = 'text/json'
     
  request.body.rewind  # Just a safety in case its already been read
  
  service = WorldcatDiscoveryService.new
  
  json = JSON.parse(request.body.read)    
  citation = Cedilla::Citation.new(json['citation']) unless json['citation'].nil?
  
  new_citation = service.process_request(citation, {})
  
  out = "\"citations\":[{\"cover_image\":\"#{new_citation.cover_image}\"}]"
  
  "{\"time\":\"#{Date.today.to_s}\",\"id\":\"#{json['id']}\",\"api_ver\":\"#{json['api_ver']}\"," + out + "}"
end



