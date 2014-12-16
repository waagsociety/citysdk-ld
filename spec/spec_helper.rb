require 'rubygems'
require 'rack/test'

ENV["RACK_ENV"] = 'test'
require File.expand_path("../../config/environment", __FILE__)

config = JSON.parse(File.read("./config.test.json"), symbolize_names: true)
$base_uri = config[:endpoint][:base_uri]

# Expects the user who executes `rspec` to also have postgres login rights - without password
system "psql postgres -c 'DROP DATABASE IF EXISTS \"#{config[:db][:database]}\"'"
system "createdb \"#{config[:db][:database]}\" -T template0 -E UTF8"
system "psql \"#{config[:db][:database]}\" -c 'CREATE EXTENSION hstore'"
system "psql \"#{config[:db][:database]}\" -c 'CREATE EXTENSION postgis'"
system "psql \"#{config[:db][:database]}\" -c 'CREATE EXTENSION pg_trgm'"

# Run migrations - initialize tables, constants and functions
system "cd db && ruby run_migrations.rb test"

def app
  CitySDKLD::API
end

def read_test_data(filename)
  File.read("./spec/data/#{filename}").force_encoding("UTF-8")
end

def read_test_data_json(filename)
  JSON.parse(read_test_data(filename), symbolize_names: true)
end

def body_json(last_response)
  JSON.parse(last_response.body, symbolize_names: true)
end

def compare_hash(h1, h2, skip_recursion = false)
  result = true
  h1.keys.each do |k|
    if h1[k] and h1[k] != ''
      result &= (h1[k] == h2[k])
    end
  end
  result &= compare_hash(h2, h1, true) unless skip_recursion
  result
end

def status_should(last_response, status)
  if last_response.status != status
    puts "\nHTTP status = #{last_response.status} (should be #{status}). API's response: \n" +
          JSON.pretty_generate(body_json(last_response))
  end
  last_response.status.should == status
end

$post_data = {}

Thread.new do
  server = TCPServer.new 9696
  loop do
    Thread.start(server.accept) do |client|
      l = client.readpartial(3000)
      $post_data = JSON.parse(l.split("\r\n")[-1], symbolize_names: true)
      puts $post_data
      client.puts "HTTP/1.0 200 OK\r\n"
      client.puts "Content-Type: text/html"
      client.puts "\r\n"
      client.puts '{"inw":"10"}' + "\r\n"
      client.close
    end
  end
end


Thread.new do
  server = TCPServer.new 9797
  loop do
    Thread.start(server.accept) do |client|
      puts ''
      l = client.readpartial(3000)
      $post_data = JSON.parse(l.split("\r\n")[-1], symbolize_names: true)
      client.puts "HTTP/1.0 200 OK\r\n"
      client.puts "Content-Type: text/html"
      client.puts "\r\n"
      client.close
    end
  end
end


RSpec.configure do |c|
  c.mock_with :rspec
  c.expect_with :rspec
end
