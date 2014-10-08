#encoding: utf-8

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

  options[:keep] = false
  opts.on("-k", "--keep_tables", "Keep OpenStreetMap data in DB after import") do |k|
    options[:keep] = k
  end
end.parse!

if options[:osm_filename].nil?
  puts 'OpenStreetMap file not specified - use -f argument'
  exit
end

env = 'development'
config = JSON.parse(File.read("#{File.dirname(__FILE__)}/../../config.#{env}.json"), symbolize_names: true)

database = Sequel.connect "postgres://#{config[:db][:user]}:#{config[:db][:password]}@#{config[:db][:host]}/#{config[:db][:database]}", encoding: 'UTF-8'

database.extension :pg_hstore

osm_filename = ARGV[0]

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

owner = config[:owner]
osm_layer = JSON.parse(File.read("#{File.dirname(__FILE__)}/osm_layer.json"), symbolize_names: true)
osm_layer[:owner] = config[:owner][:name]

osm_schema_exists = database["SELECT TRUE FROM information_schema.schemata WHERE schema_name = 'osm'"].count > 0

unless osm_schema_exists and options[:keep]
  database.run <<-SQL
    DROP SCHEMA IF EXISTS osm CASCADE;
  SQL

  # Use osm2pgsql to read data from osm file into database
  osm2pgsql = "osm2pgsql --slim -j -d #{config[:db][:database]} -H #{config[:db][:host]} -l -C6000 -U postgres #{options[:osm_filename]}"
  unless system osm2pgsql
    puts "Executing osm2pgsql failed... Is osm2pgsql installed?"
    exit
  end
  database.run File.read("#{File.dirname(__FILE__)}/osm_schema.sql")
end

conn = Faraday.new(url: config[:endpoint][:url])

# Check if owner exists in CitySDK LD API endpoint
resp = conn.get "/owners/#{owner[:name]}"
if resp.status != 200
  puts "Owner not found: '#{owner[:name]}'"
  exit
end

# Authenticate!
resp = conn.get "/session?name=#{owner[:name]}&password=#{owner[:password]}"
if resp.status.between? 200, 299
  json = JSON.parse resp.body, symbolize_names: true
  if json.has_key? :session_key
    conn.headers['X-Auth'] = json[:session_key]
  else
    raise Exception.new 'Invalid credentials'
  end
else
  raise Exception.new resp.body
end

# Delete osm layer in API
resp = conn.delete "/layers/#{osm_layer[:name]}"
unless [204, 404].include? resp.status
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

osm_tables = [
  {table: 'planet_osm_point', id_prefix: 'n'},
  {table: 'planet_osm_line', id_prefix: 'w'},
  {table: 'planet_osm_polygon', id_prefix: 'w'}
  # {table: 'planet_osm_rels', id_prefix: 'r'}
]
# TODO: support OpenStreetMap relations.
# Prerequisite: support members/sets.

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
    puts "HTTP status #{response.status}: " + JSON.parse(response.body)['error']
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
