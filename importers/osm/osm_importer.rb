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

  options[:remove] = false
  opts.on("-r", "--remove", "Remove OpenStreetMap data DB after import") do |r|
    options[:remove] = r
  end

  opts.on("-d", "--database DATABASE", String, "Name of database to use (default = 'osm')") do |d|
    options[:osm_database] = d
  end
end.parse!

env = 'development'
config = JSON.parse(File.read("#{File.dirname(__FILE__)}/../../config.#{env}.json"), symbolize_names: true)
osm_db_config = config[:db]
osm_db_config[:database] = 'osm'

if config.has_key? :osm
  osm_db_config.merge! config[:osm]
end

if options[:osm_database]
  osm_db_config[:database] = options[:osm_database]
end

database = Sequel.connect "postgres://#{osm_db_config[:user]}:#{osm_db_config[:password]}@#{osm_db_config[:host]}/#{osm_db_config[:database]}", encoding: 'UTF-8'
database.extension :pg_hstore
database.extension :pg_streaming
database.stream_all_queries = true

osm_tables = [
  'planet_osm_line',
  'planet_osm_nodes',
  'planet_osm_point',
  'planet_osm_polygon',
  'planet_osm_rels',
  'planet_osm_roads',
  'planet_osm_ways'
]

count_osm_tables = database[:pg_class].where(relname: osm_tables).count

def osm2pgsql(options, osm_db_config)
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

  # Use osm2pgsql to read data from osm file into database
  cache_size = osm_db_config[:cache_size] or 6000
  export = "export PGPASS=#{osm_db_config[:password]}"
  osm2pgsql = "osm2pgsql --slim -j -d #{osm_db_config[:database]} -H #{osm_db_config[:host]}"
      + " -l -C#{cache_size} -U #{osm_db_config[:user]} #{options[:osm_filename]}"

  unless system "#{export}; #{osm2pgsql}"
    puts "Executing osm2pgsql failed... Is osm2pgsql installed?"
    exit
  end
end

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

def import_osm(database, config, options)
  owner = config[:owner]
  osm_layer = JSON.parse(File.read("#{File.dirname(__FILE__)}/osm_layer.json"), symbolize_names: true)
  osm_layer[:owner] = config[:owner][:name]

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

  batch_size = 50
  osm_tables.each do |osm_table|
    objects = []
    count = 0
    database.fetch(select % [osm_table[:table]]).stream.all do |row|
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
        puts "Table: #{osm_table[:table]}, objects: #{count}, status: #{response.status}"
        objects = []
      end
    end
    write_objects conn, osm_layer[:name], objects if objects.length > 0
  end

  if options[:remove]
    # database.run <<-SQL
    #   DROP SCHEMA IF EXISTS osm CASCADE;
    # SQL
  end
end

if options[:osm_filename]
  if count_osm_tables == 0
    osm2pgsql(options, osm_db_config)
    import_osm(database, config, options)
  else
    puts "OpenStreetMap tables encountered (`planet_osm_*`) in database #{osm_db_config[:database]}. Remove -f option, or delete tables."
    exit
  end
elsif count_osm_tables == 7
  import_osm(database, config, options)
else
  puts "No complete OpenStreetMap import available in database #{osm_db_config[:database]}, and no OSM file specified. Use -f option."
  exit
end
