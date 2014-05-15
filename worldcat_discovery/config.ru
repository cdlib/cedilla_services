require 'rubygems'
require 'bundler'
require 'sinatra'
require 'yaml'

require 'rdf/turtle'
require 'rdf/rdfxml'
require 'rest_client'

require 'cedilla'

require('./worldcat_discovery.rb')

configure do
  LOGGER = Logger.new("worldcat_discovery.log")
  enable :logging, :dump_errors
  set :raise_errors, true
  
  set :environment, :development #ENV['RACK_ENV'].to_sym
  set :run, true
end

# -------------------------------------------------------------------------
run WorldcatDiscovery.new