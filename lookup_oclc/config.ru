require 'rubygems'
require 'bundler'
require 'sinatra'
require 'yaml'
require('./oclc_xid.rb')

#Bundler.require(:default, ENV['RACK_ENV'].to_sym)

set :environment, :development #ENV['RACK_ENV'].to_sym
set :run, true
set :raise_errors, true

# -------------------------------------------------------------------------
run OclcXid.new