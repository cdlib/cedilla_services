require 'rubygems'
require 'bundler'
require 'sinatra'
require 'yaml'
require('./oclc_lc_authority.rb')

configure do
  LOGGER = Logger.new("oclc_lc_authority.log")
  enable :logging, :dump_errors
  set :raise_errors, true
  
  set :environment, :development #ENV['RACK_ENV'].to_sym
  set :run, true
end

# -------------------------------------------------------------------------
run OclcLcAuthority.new