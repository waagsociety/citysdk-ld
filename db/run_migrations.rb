#!/usr/bin/env ruby

require 'json'

environments = [
  'test',
  'development'
]

if ARGV.length == 0 or not environments.include? ARGV[0]
  puts "Please specify one of the following environments: #{environments.join(', ')}"
  exit
end

env = ARGV[0]
config = JSON.parse(File.read("../config.#{env}.json"), symbolize_names: true)

database = "postgres://#{config[:db][:user]}:#{config[:db][:password]}@#{config[:db][:host]}/#{config[:db][:database]}"

if ARGV[1] then
  command = "sequel -m migrations -M #{ARGV[1]} #{database}"
else
  command = "sequel -m migrations #{database}"
end

system command
