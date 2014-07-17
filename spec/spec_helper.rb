require 'rubygems'
require 'rack/test'

ENV["RACK_ENV"] = 'test'
require File.expand_path("../../config/environment", __FILE__)

config = JSON.parse(File.read("./config.test.json"), symbolize_names: true)

# Expects the user who executes `rspec` to also have postgres login rights - without password
system "psql postgres -c 'DROP DATABASE IF EXISTS \"#{config[:db][:database]}\"'"
system "createdb \"#{config[:db][:database]}\""
system "psql \"#{config[:db][:database]}\" -c 'CREATE EXTENSION hstore'"
system "psql \"#{config[:db][:database]}\" -c 'CREATE EXTENSION postgis'"
system "psql \"#{config[:db][:database]}\" -c 'CREATE EXTENSION pg_trgm'"

# Run migrations - initialize tables, constants and functions
system "cd db && ruby run_migrations.rb test"

RSpec.configure do |c|
  c.mock_with :rspec
  c.expect_with :rspec
end
