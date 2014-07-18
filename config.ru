require 'rubygems'
require 'bundler'
require 'sinatra'
require 'yaml'

require 'rdf/turtle'
require 'rdf/rdfxml'
require 'rest_client'

require 'cedilla'
require('./cedilla_services.rb')

configure do
  LOGGER = Logger.new("cedilla_services.log")
  enable :logging, :dump_errors
  set :raise_errors, true
  
  set :environment, :development #ENV['RACK_ENV'].to_sym
  set :run, true
end

# -------------------------------------------------------------------------
run CedillaServices.new