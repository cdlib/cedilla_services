require 'rubygems'
require 'bundler'
require 'sinatra'

Bundler.require(:default, ENV['RACK_ENV'].to_sym)

set :environment, ENV['RACK_ENV'].to_sym

configure do
  set :root, File.dirname(__FILE__)
  set :bind, 'localhost'
  set :port, 3101
end

disable :run, :reload

# Hack to protect against nil header values. For some reason requests coming directly from a
# browser NOT through the JS EventSource library are passing a nil value for: Access-Control-Allow-Origin
#
# This fix comes from a pull request made to the phusion/passenger team
# https://github.com/phusion/passenger/pull/89
#
# They refused to incorporate the fix stating that the Rack specifications do not allow nil headers
# they say the application should correct the issue. Since we have no control over browser code
# We ovveride the phusion_passenger/rack/thread_handler_extension.rb
if defined?(PhusionPassenger)
  require './passenger_hack.rb'
end

require('./service.rb')

run AggregatorServiceTest.new('./config/service_test.yaml')