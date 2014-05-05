require 'rubygems'
require 'bundler'
require 'sinatra'
require 'cedilla'
require 'yaml'
require 'marc'
require('./oclc_lc_authority.rb')

#Bundler.require(:default, ENV['RACK_ENV'].to_sym)

set :environment, :development #ENV['RACK_ENV'].to_sym
set :run, true
set :raise_errors, true

# -------------------------------------------------------------------------
run OclcLcAuthority.new