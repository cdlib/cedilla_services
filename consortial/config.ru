require 'rubygems'
require 'bundler'
require 'sinatra'
require 'sinatra/base'
require 'logger'
require 'yaml'
require 'cedilla'
require './consortial.rb'

configure do
  LOGGER = Logger.new("consortial.log")
  enable :logging, :dump_errors
  set :raise_errors, true
  
  set :environment, :development #ENV['RACK_ENV'].to_sym
  set :run, true
end

# -------------------------------------------------------------------------
run Consortial.new