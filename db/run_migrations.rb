#!/usr/bin/env ruby

require 'json'

config = JSON.parse(File.read('../config.json'), symbolize_names: true)

database = "postgres://#{config[:db][:user]}:#{config[:db][:password]}@#{config[:db][:host]}/#{config[:db][:database]}"

if ARGV[0] then
  command = "sequel -m migrations -M #{ARGV[0]} #{database}"
else
  command = "sequel -m migrations #{database}"
end

system command
