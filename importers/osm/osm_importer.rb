require 'json'
require 'sequel'
require 'faraday'

unless ARGV.length == 2
  puts 'Usage: osm_importer.rb <osm_file> <owner>'
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
unless File.file? osm_filename
  puts "OSM file does not exist: '#{osm_filename}'"
  exit
end
accepted_formats = ['.osm', '.pbf', '.bz2']
unless accepted_formats.include? File.extname(osm_filename)
  puts "OSM file is not valid. Extension must be one of the following: #{accepted_formats.join(', ')}"
  exit
end

osm_layer = JSON.parse(File.read("./osm_layer.json"), symbolize_names: true)
osm_layer[:owner] = owner

# Delete osm layer in API
conn.delete "/layers/#{osm_layer[:name]}"
if response.status != 200
  puts "Error deleting layer '#{osm_layer[:name]}'"
  exit
end

# Create new, empty osm layer
response = conn.post '/layers', osm_layer.to_json
if response.status != 201
  puts "Error creating layer '#{osm_layer[:name]}'"
  exit
end

# Use osm2pgsql to read data from osm file into database
# osm2pgsql = "osm2pgsql --slim -j -d #{config[:db][:database]} -H #{config[:db][:host]} -l -C6000 -U postgres #{osm_filename}"
# system osm2pgsql
# database.run File.read('./osm_schema.sql')

osm_tables = [
  {table: 'planet_osm_point', id_prefix: 'n'},
  {table: 'planet_osm_line', id_prefix: 'w'},
  {table: 'planet_osm_polygon', id_prefix: 'w'}
]
# TODO: support 'planet_osm_rels': {table: 'planet_osm_rels', id_prefix: 'r'}

select = <<-SQL
  SELECT
    abs(osm_id)::text AS id,
    name AS title,
    ST_AsGeoJSON(way) AS geometry,
    tags AS data
  FROM %s
SQL

def write_objects(conn, osm_layer, objects)
  geojson = {
    type: 'FeatureCollection',
    features: objects
  }
  response = conn.post "/layers/#{osm_layer}/objects", geojson.to_json
  puts response.status
  if response.status != 201
    puts objects.map {|o| o[:properties][:id] }.inspect
  end
  #sleep 0.5
end

batch_size = 100
objects = []
osm_tables.each do |osm_table|
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
      write_objects conn, osm_layer[:name], objects
      objects = []
    end
  end
end
write_objects objects

# database.run <<-SQL
#   DROP SCHEMA IF EXISTS osm CASCADE;
# SQL

