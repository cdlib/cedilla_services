require 'rack/test'

require_relative './test_helper'
require_relative '../cedilla_services.rb'

WebMock.disable_net_connect!(:allow_localhost => true)


class CedillaServicesTest < Minitest::Test
  include Rack::Test::Methods
  
  def app
    CedillaServices.new
  end
  
  # --------------------------------------------------------------------------------------------------
  def test_to_camel_case
    assert_equal "MyTest", CedillaServices.to_camel_case("my_test"), "Was expecting 'my_test' to translate to MyTest!"
    assert_equal "Mytest", CedillaServices.to_camel_case("mytest"), "Was expecting 'mytest' to translate to Mytest!"
  end
  
  # --------------------------------------------------------------------------------------------------
  def test_startup
    yaml = nil
    if File.exists?(File.dirname(__FILE__) + '/config/app.yml')
      yaml = YAML.load_file('./config/app.yml')
    else
      puts "Warning ./config/app.yml not found! Using ./config/app.yml.example instead."
      yaml = YAML.load_file('./config/app.yml.example')
    end
    
    yaml['services'].each do |service, defs|
      get "/#{service}"
      
      # Only enabled services are started
      assert_equal (defs['enabled'] ? true : false), last_response.ok?, "Was expecting an HTTP #{(defs['enabled'] ? 200 : 404)} for #{service}!"
      
      if defs['enabled']
        # Question mark was replaced with service name 
        assert last_response.body.include?(CedillaServices.to_camel_case(service)), "Was expecting the response to contain the service name, #{service}!"
        
        assert Object.const_defined?("#{CedillaServices.to_camel_case(service)}Service"), "Was expecting the #{service} service to have a class definition!"
      end
      
    end
    
  end
  
end