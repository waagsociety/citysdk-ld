# encoding: UTF-8

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'api'))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'app'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'boot'

Bundler.require :default, ENV['RACK_ENV']

Dir[File.expand_path('../../api/*.rb', __FILE__)].each do |f|
  require f
end

Dir[File.expand_path('../../serializers/*.rb', __FILE__)].each do |f|
  require f
end

require 'api'
require 'ngsi_query'
require 'endpoint_query'
require 'citysdkld_app'
require 'utils'
