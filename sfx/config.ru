require 'rubygems'
require 'bundler'
require 'sinatra'
require 'cedilla'
require 'yaml'
require('./sfx.rb')

#Bundler.require(:default, ENV['RACK_ENV'].to_sym)

set :environment, :development #ENV['RACK_ENV'].to_sym
set :run, true
set :raise_errors, true

# -------------------------------------------------------------------------
run Sfx.new