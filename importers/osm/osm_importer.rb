#!/usr/bin/ruby

require 'json'
require 'sequel'
require 'faraday'
require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: osm_importer.rb [options]"

  opts.on("-f", "--filename FILENAME", String, "OpenStreetMap file") do |f|
    options[:osm_filename] = f
  end

  opts.on("-o", "--owner OWNER", String, "CitySDK LD API owner") do |o|
    options[:owner] = o
  end

  options[:keep] = false
  opts.on("-k", "--keep_tables", "Keep OpenStreetMap data in DB after import") do |k|
    options[:keep] = k
  end

end.parse!

if options[:owner].nil?
  puts 'Owner not specified - use -o argument'
  exit
end

if options[:osm_filename].nil?
  puts 'OpenStreetMap file not specified - use -f argument'
  exit
end

env = 'development'
config = JSON.parse(File.read("../../config.#{env}.json"), symbolize_names: true)

database = Sequel.connect "postgres://#{config[:db][:user]}:#{config[:db][:password]}@#{config[:db][:host]}/#{config[:db][:database]}"
database.extension :pg_hstore

osm_filename = ARGV[0]
owner = ARGV[1]

conn = Faraday.new(url: config[:endpoint][:url])

# Check if owner exists in CitySDK LD API endpoint
response = conn.get "/owners/#{owner}"
if response.status != 200
  puts "Owner not found: '#{owner}'"
  exit
end

# Check if OSM file exists and is valid
unless File.file? options[:osm_filename]
  puts "OSM file does not exist: '#{options[:osm_filename]}'"
  exit
end
accepted_formats = ['.osm', '.pbf', '.bz2']
unless accepted_formats.include? File.extname(options[:osm_filename])
  puts "OSM file is not valid. Extension must be one of the following: #{accepted_formats.join(', ')}"
  exit
end

osm_layer = JSON.parse(File.read("./osm_layer.json"), symbolize_names: true)
osm_layer[:owner] = options[:owner]

# Delete osm layer in API
conn.delete "/layers/#{osm_layer[:name]}"
if response.status != 200
  puts "Error deleting layer '#{osm_layer[:name]}'"
  exit
end

# Create new, empty osm layer
response = conn.post do |req|
  req.url '/layers'
  req.headers['Content-Type'] = 'application/json'
  req.body = osm_layer.to_json
end
if response.status != 201
  puts "Error creating layer '#{osm_layer[:name]}'"
  exit
end

osm_schema_exists = database["SELECT TRUE FROM information_schema.schemata WHERE schema_name = 'osm'"].count > 0

unless osm_schema_exists and options[:keep]
  database.run <<-SQL
    DROP SCHEMA IF EXISTS osm CASCADE;
  SQL

  # Use osm2pgsql to read data from osm file into database
  osm2pgsql = "osm2pgsql --slim -j -d #{config[:db][:database]} -H #{config[:db][:host]} -l -C6000 -U postgres #{options[:osm_filename]}"
  system osm2pgsql
  database.run File.read('./osm_schema.sql')
end

osm_tables = [
  {table: 'planet_osm_point', id_prefix: 'n'},
  {table: 'planet_osm_line', id_prefix: 'w'},
  {table: 'planet_osm_polygon', id_prefix: 'w'}
]
# TODO: support 'planet_osm_rels': {table: 'planet_osm_rels', id_prefix: 'r'}
# Finish members support first!

select = <<-SQL
  SELECT
    osm_id::text AS id,
    name AS title,
    ST_AsGeoJSON(way) AS geometry,
    tags AS data
  FROM %s
  WHERE osm_id > 0
SQL

def write_objects(conn, osm_layer, objects)
  geojson = {
    type: 'FeatureCollection',
    features: objects
  }
  response = conn.post do |req|
    req.url "/layers/#{osm_layer}/objects"
    req.headers['Content-Type'] = 'application/json'
    req.body = geojson.to_json
  end
  if response.status != 201
    puts response.inspect
  end
  response
end

batch_size = 50
osm_tables.each do |osm_table|
  objects = []
  count = 0
  total = database["osm__#{osm_table[:table]}".to_sym].count
  database.fetch(select % ["osm.#{osm_table[:table]}"]).all do |row|
    objects << {
      type: "Feature",
      properties: {
        id: "#{osm_table[:id_prefix]}#{row[:id]}",
        title: row[:title],
        data: row[:data]
      },
      geometry: JSON.parse(row[:geometry])
    }
    if objects.length >= batch_size
      response = write_objects conn, osm_layer[:name], objects
      count += batch_size
      puts "Table: #{osm_table[:table]}, objects: #{count}/#{total}, status: #{response.status}"
      objects = []
    end
  end
  write_objects conn, osm_layer[:name], objects if objects.length > 0
end

unless options[:keep]
  database.run <<-SQL
    DROP SCHEMA IF EXISTS osm CASCADE;
  SQL
end
