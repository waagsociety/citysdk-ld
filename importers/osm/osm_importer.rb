#encoding: utf-8

require 'json'
require 'sequel'
require 'optparse'
require 'citysdk'
include CitySDK

# ============================ Parse command line arguments ============================

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: osm_importer.rb [options]"

  opts.on("-f", "--filename FILENAME", String, "OpenStreetMap file") do |f|
    options[:osm_filename] = f
  end

  options[:remove] = false
  opts.on("-r", "--remove", "Remove OpenStreetMap database after import") do |r|
    options[:remove] = r
  end

  opts.on("-d", "--database DATABASE", String, "Name of database to use (default = 'osm')") do |d|
    options[:osm_database] = d
  end
end.parse!

# ============================ Get endpoint and owner credentials ============================

if ENV.has_key? 'CITYSDK_CONFIG' and ENV['CITYSDK_CONFIG'].length
  config_path = ENV['CITYSDK_CONFIG']
else
  puts "CITYSDK_CONFIG environment variable not set,"
  puts "CITYSDK_CONFIG should contain path of CitySDK LD API configuration file"
  exit!(-1)
end

config = nil
begin
  config = JSON.parse(File.read(config_path), {symbolize_names: true})
rescue Exception => e
  puts <<-ERROR
  Error loading CitySDK configuration file...
  Please set CITYSDK_CONFIG environment variable, or pass configuration file as a command line parameter
  Error message: #{e.message}
  ERROR
  exit!(-1)
end

osm_db_config = config[:db]
osm_db_config[:database] = 'osm'

if config.has_key? :osm
  osm_db_config.merge! config[:osm]
end

if options[:osm_database]
  osm_db_config[:database] = options[:osm_database]
end

# ==================================== Connect to OSM database ======================================

database = Sequel.connect "postgres://#{osm_db_config[:user]}:#{osm_db_config[:password]}@#{osm_db_config[:host]}/#{osm_db_config[:database]}", encoding: 'UTF-8'
database.extension :pg_hstore
# database.extension :pg_streaming
# database.stream_all_queries = true

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

# ================================== Function which runs osm2pgsql ====================================

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

def import_osm(database, config, options)

  # ==================================== Connect to API ======================================

  api = API.new(config[:endpoint][:url])
  if not api.authenticate(config[:owner][:name], config[:owner][:password])
    puts 'Error authenticating with API'
    exit!(-1)
  end
  api.set_layer 'osm'

  owner = config[:owner]
  osm_layer = JSON.parse(File.read("#{File.dirname(__FILE__)}/osm_layer.json"), symbolize_names: true)
  osm_layer[:owner] = config[:owner][:name]

  puts "Deleting layer 'osm' and objects, if layer already exists..."
  begin
    api.delete("/layers/osm")
  rescue CitySDK::HostException => e
  end
  puts "Creating layer 'osm'"
  api.post("/layers", osm_layer)

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

  osm_tables.each do |osm_table|
    count = 0
    database.fetch(select % [osm_table[:table]]).use_cursor.each do |row|
      feature = {
        type: "Feature",
        properties: {
          id: "#{osm_table[:id_prefix]}#{row[:id]}",
          title: row[:title],
          data: row[:data]
        },
        geometry: JSON.parse(row[:geometry])
      }

      api.create_object feature
      count += 1

      if count % 500 == 0
        puts "Table: #{osm_table[:table]}, objects: #{count}"
      end
    end
  end

  if options[:remove]
    database.run <<-SQL
      DROP SCHEMA IF EXISTS osm CASCADE;
    SQL
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
