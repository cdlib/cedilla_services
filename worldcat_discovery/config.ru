require 'rubygems'
require 'bundler'
require 'sinatra'
require 'rdf/rdfxml'
require 'json/ld'
require 'equivalent-xml'
require 'oclc/auth'
require 'cedilla'
require 'yaml'
require('./worldcat_discovery.rb')

#Bundler.require(:default, ENV['RACK_ENV'].to_sym)

set :environment, :development #ENV['RACK_ENV'].to_sym
set :run, true
set :raise_errors, true

enable :sessions

app_home = File.expand_path(File.dirname(__FILE__))
LANGUAGES = YAML::load(File.read("#{app_home}/config/languages.yml"))
FORMATS = YAML::load(File.read("#{app_home}/config/formats.yml"))

# -------------------------------------------------------------------------
run WorldcatDiscovery.new