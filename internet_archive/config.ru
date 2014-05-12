require 'rubygems'
require 'bundler'
require 'sinatra'
require('./internet_archive.rb')

configure do
  LOGGER = Logger.new("internet_archive.log")
  enable :logging, :dump_errors
  set :raise_errors, true
  
  set :environment, :development #ENV['RACK_ENV'].to_sym
  set :run, true
end

run InternetArchive.new