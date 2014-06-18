require 'rubygems'
require 'rack/test'
require File.expand_path("../../config/environment", __FILE__)

env = 'test'
ENV["RACK_ENV"] ||= env

config = JSON.parse(File.read("./config.#{env}.json"), symbolize_names: true)

# Expects the user who executes `rspec` to also have postgres login rights - without password
system "psql postgres -c 'DROP DATABASE IF EXISTS \"#{config[:db][:database]}\"'"
system "createdb \"#{config[:db][:database]}\""
system "psql \"#{config[:db][:database]}\" -c 'CREATE EXTENSION hstore'"
system "psql \"#{config[:db][:database]}\" -c 'CREATE EXTENSION postgis'"
system "psql \"#{config[:db][:database]}\" -c 'CREATE EXTENSION pg_trgm'"

# Run migrations - initialize tables, constants and functions
system "cd db && ruby run_migrations.rb #{env}"

RSpec.configure do |c|
  c.mock_with :rspec
  c.expect_with :rspec
end
