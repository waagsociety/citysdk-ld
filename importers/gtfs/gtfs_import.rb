#!/usr/bin/env ruby
require "pg"
require "csv"
require "json"
require 'socket'
require 'tempfile'
require 'getoptlong'
require './gtfs_util.rb'
require './gtfs_layers.rb'

$newDir = ''
$prefix = ''
$quote = '"'


$gtfs_files = ['agency', 'feed_info', 'calendar_dates', 'stops', 'routes', 'trips', 'stop_times','shapes']

def create_schema
  $postgres.exec("drop schema if exists igtfs cascade; create schema igtfs;")
end

def get_columns(f)
  a = nil
  begin
    File.open("#{$newDir}/#{f}.txt", "r:bom|utf-8") do |fd|
      a = fd.gets.strip.split(',')
    end
  rescue
  end
  a
end




$c_types = {

  'shapes' => {
    'shape_id' => 'text',
    'shape_pt_lat' => 'text',
    'shape_pt_lon' => 'text',
    'shape_pt_sequence' => 'integer'
  },

  'feed_info' => {
    'feed_publisher_name' => 'text',
    'feed_publisher_url' => 'text',
    'feed_lang' => 'text',
    'feed_start_date' => 'date',
    'feed_end_date' => 'date',
    'feed_valid_from' => 'date',
    'feed_valid_to' => 'date',
    'feed_version' => 'text'
  },

  'agency' => {
    'agency_id' => 'text primary key',
    'agency_name' => 'text',
    'agency_url' => 'text',
    'agency_timezone' => 'text',
    'agency_lang' => 'text'
  },

  'calendar_dates' => {
    'service_id' => 'text',
    'date' => 'date',
    'exception_type' => 'smallint'
  },

  'stops' => {
    'stop_id' => 'text primary key',
    'stop_name' => 'text',
    'location_type' => 'smallint',
    'parent_station' => 'text',
    'wheelchair_boarding' => 'smallint',
    'platform_code' => 'text',
    'stop_lat' => 'float',
    'stop_lon' => 'float'
  },

  'routes' => {
    'route_id' => 'text primary key',
    'agency_id' => 'text',
    'route_short_name' => 'text',
    'route_long_name' => 'text',
    'route_type' => 'smallint'
  },

  'trips' => {
    'route_id' => 'text',
    'service_id' => 'text',
    'trip_id' => 'text',
    'trip_headsign' => 'text',
    'shape_id' => 'text',
    'direction_id' => 'smallint',
    'wheelchair_accessible' => 'smallint',
    'trip_bikes_allowed' => 'smallint'
  },

  'stop_times' => {
    'trip_id' => 'text',
    'arrival_time' => 'text',
    'departure_time' => 'text',
    'stop_id' => 'text',
    'stop_sequence' => 'smallint',
    'stop_headsign' => 'text',
    'pickup_type' => 'smallint',
    'drop_off_type' => 'smallint'
  }
}


def calendar_dates
  one_file('calendar_dates')
  $zrp.p "Merging calendar_dates.."


  $postgres.exec "drop index if exists calendar_dates_service_id;"


  $postgres.exec <<-SQL
    insert into gtfs.calendar_dates select
      ('#{$prefix}' || service_id), date, exception_type
    from igtfs.calendar_dates;
  SQL

  $postgres.exec "create table calendar_dates as select distinct * from gtfs.calendar_dates;"
  $postgres.exec "drop table gtfs.calendar_dates;"
  $postgres.exec "alter table calendar_dates set schema gtfs;"
  $postgres.exec "create index calendar_dates_service_id on gtfs.calendar_dates(service_id);"

end


def stops
  cls = one_file('stops')

  $zrp.p "Merging stops.."

  select = "i.stop_name"
  select += cls.include?('location_type') ? ",i.location_type" : ", 0"
  select += cls.include?('parent_station') ? ",i.parent_station" : ", ''"
  select += cls.include?('platform_code') ? ", i.platform_code" : ", ''"
  select += ",i.location"
  select += cls.include?('wheelchair_boarding') ? ", i.wheelchair_boarding" : ", 0"

  select2 = "stop_id,stop_name,location_type,parent_station, wheelchair_boarding, platform_code,location"
  select2.gsub!('location_type',"0") if !cls.include?('location_type')
  select2.gsub!('parent_station',"''") if !cls.include?('parent_station')
  select2.gsub!('wheelchair_boarding',"0") if !cls.include?('wheelchair_boarding')
  select2.gsub!('platform_code',"''") if !cls.include?('platform_code')


  $postgres.exec "alter table igtfs.stops add column location geometry(point,4326)"
  $postgres.exec "update igtfs.stops set (stop_id,location) = ('#{$prefix}' || stop_id, ST_SetSRID(ST_Point(stop_lon,stop_lat),4326))"
  $postgres.exec "update igtfs.stops set parent_station = '' where parent_station is NULL" if cls.include?('parent_station')
  $postgres.exec "update igtfs.stops set wheelchair_boarding = 0 where wheelchair_boarding is NULL" if cls.include?('wheelchair_boarding')
  $postgres.exec "update igtfs.stops set platform_code = '' where platform_code is NULL" if cls.include?('platform_code')
  $postgres.exec "update igtfs.stops set location_type = 0 where location_type is NULL" if cls.include?('location_type')

  $postgres.exec <<-SQL
    WITH upsert as
    (update gtfs.stops g set
      (stop_name,location_type,parent_station,platform_code,location,wheelchair_boarding) =
      (#{select})
      from igtfs.stops i where g.stop_id=i.stop_id
        returning g.stop_id
    )
    insert into gtfs.stops select
      #{select2}
    from igtfs.stops a where a.stop_id not in (select stop_id from upsert);
  SQL
end


#agency_id,agency_name,agency_url,agency_timezone

def agency
  cls = one_file('agency')
  if cls
    $zrp.p "Merging agency.."

    select  = "agency_id,agency_name,agency_url,agency_timezone,agency_lang"
    iselect = "i.agency_name,i.agency_url,i.agency_timezone,i.agency_lang"

    if !cls.include?('agency_lang')
      select.gsub!('agency_lang',"''")
      iselect.gsub!('i.agency_lang',"''")
    end

    $postgres.exec <<-SQL
      WITH upsert as
      (update gtfs.agency g set
        (agency_name,agency_url,agency_timezone,agency_lang) =
        (#{iselect})
        from igtfs.agency i where g.agency_id=i.agency_id
          returning g.agency_id
      )
      insert into gtfs.agency select
        #{select}
      from igtfs.agency a where a.agency_id not in (select agency_id from upsert);
    SQL
  end
end


def shapes
  cls = one_file('shapes')
  if cls
    $zrp.p "Merging shapes.."
    $postgres.exec <<-SQL
      delete from gtfs.shapes g
      where g.shape_id in (select distinct shape_id from igtfs.shapes);
      insert into gtfs.shapes select
        shape_id,shape_pt_lat,shape_pt_lon,shape_pt_sequence
      from igtfs.shapes;
    SQL
  end
end


def feed_info
  cls = one_file('feed_info')
  if cls
    a = []
    CSV.foreach("#{$newDir}/agency.txt", :quote_char => '"', :col_sep =>',',:headers => true, :row_sep =>:auto) do |row|
      a << row['agency_name']
    end
    a = $postgres.escape(a.join(', '))

    select = "feed_publisher_name,feed_publisher_url,feed_lang,feed_start_date,feed_end_date,feed_version,'#{a}','#{Time.now.strftime('%Y-%m-%d')}'"
    select.gsub!('feed_end_date','feed_valid_to') if cls.include?('feed_valid_to')
    select.gsub!('feed_start_date','feed_valid_from') if cls.include?('feed_valid_from')

    $postgres.exec <<-SQL
      delete from gtfs.feed_info g
      using igtfs.feed_info i
      where g.feed_version = i.feed_version;
      insert into gtfs.feed_info select
        #{select}
      from igtfs.feed_info;
    SQL
  end
end


def routes
  cls = one_file('routes')

  $zrp.p "Merging routes.."

  select  = "route_id,agency_id,route_short_name,route_long_name,route_type"
  iselect = "i.agency_id,i.route_short_name,i.route_long_name,i.route_type"
  if !cls.include?('agency_id')
    select.gsub!('agency_id',"''")
    iselect.gsub!('i.agency_id',"''")
  end

  $postgres.exec "update igtfs.routes set (route_id) = ('#{$prefix}' || route_id)"

  $postgres.exec "update igtfs.routes set route_short_name = route_long_name where route_short_name is NULL"

  $postgres.exec <<-SQL
    WITH upsert as
    (update gtfs.routes g set
      (agency_id,route_short_name,route_long_name,route_type) =
      (#{iselect})
      from igtfs.routes i where g.route_id=i.route_id
        returning g.route_id
    )
    insert into gtfs.routes select
      #{select}
    from igtfs.routes a where a.route_id not in (select route_id from upsert);
  SQL
end


def stop_times
  cls = one_file('stop_times')

  $postgres.exec "drop index if exists gtfs.stop_times_trip_id;"
  $postgres.exec "drop index if exists gtfs.stop_times_stop_id;"
  $postgres.exec "drop index if exists gtfs.stop_times_departure_time;"
  $postgres.exec "drop index if exists gtfs.stop_times_stop_id_trip_id;"

  select = "'#{$prefix}' || trip_id, arrival_time, departure_time, '#{$prefix}' || stop_id, stop_sequence, stop_headsign, pickup_type, drop_off_type"
  select.gsub!('stop_headsign',"''") if !cls.include?('stop_headsign')
  select.gsub!('pickup_type','0') if !cls.include?('pickup_type')
  select.gsub!('drop_off_type','0') if !cls.include?('drop_off_type')

  $zrp.p "Merging stop_times.."
  $postgres.exec <<-SQL
    insert into gtfs.stop_times select
      #{select}
    from igtfs.stop_times where igtfs.stop_times.departure_time != '';
  SQL

  $postgres.exec "create table stop_times as select distinct * from gtfs.stop_times;"
  $postgres.exec "drop table gtfs.stop_times;"
  $postgres.exec "alter table stop_times set schema gtfs;"


  $zrp.p "Create index stop_times(stop_id,trip_id).."
  $postgres.exec "create index stop_times_stop_id_trip_id on gtfs.stop_times using btree(trip_id, stop_id);"
  $zrp.p "Create index stop_times(trip_id).."
  $postgres.exec "create index stop_times_trip_id on gtfs.stop_times(trip_id);"
  $zrp.p "Create index stop_times(stop_id).."
  $postgres.exec "create index stop_times_stop_id on gtfs.stop_times(stop_id);"
  $zrp.p "Create index stop_times(departure_time).."
  $postgres.exec "create index stop_times_departure_time on gtfs.stop_times(departure_time);"

end



def trips
  cls = one_file('trips')
  if(cls)
    select = "'#{$prefix}' || route_id, '#{$prefix}' || service_id, '#{$prefix}' || trip_id"
    select += cls.include?('trip_headsign') ? ", trip_headsign" : ", ''"
    select += cls.include?('direction_id') ? ", direction_id" : ", 0"
    select += cls.include?('wheelchair_accessible') ? ", wheelchair_accessible" : ", 0"
    select += cls.include?('trip_bikes_allowed') ? ", trip_bikes_allowed" : ", 0"
    select += cls.include?('shape_id') ? ", '#{$prefix}' || shape_id" : ", ''"

    $postgres.exec "update igtfs.trips set direction_id = 0 where direction_id is NULL" if cls.include?('direction_id')

    $zrp.p "Merging trips.."

    $postgres.exec <<-SQL
      insert into gtfs.trips select
        #{select}
      from igtfs.trips;
    SQL

    $postgres.exec "create table trips as select distinct * from gtfs.trips;"
    $postgres.exec "drop table gtfs.trips;"
    $postgres.exec "alter table trips set schema gtfs;"
    $postgres.exec "create index trips_trip_id on gtfs.trips(trip_id);"
    $postgres.exec "create index trips_route_id on gtfs.trips(route_id);"
    $postgres.exec "create index trips_direction_id on gtfs.trips(direction_id);"

  end
end



def one_file(f)

  $zrp.n
  $zrp.p "Copying #{f} from disk.."

  columns = get_columns(f)
  if(columns)
    ca = []
    columns.each do |c|
      ca << "#{c} #{$c_types[f][c] || 'text'}"
    end
    $postgres.exec "set client_encoding to 'UTF8'"
    $postgres.exec "create table igtfs.#{f} (#{ca.join(',')})"
    $postgres.exec "copy igtfs.#{f} from '#{$newDir}/#{f}.txt' QUOTE '#{$quote}' CSV HEADER"
    columns
  end
end


def copy_tables()
  create_schema
  feed_info
  agency
  calendar_dates
  routes
  trips
  stops
  stop_times
  shapes
end




class Zrp
  def initialize() $stderr.write "\033[s" end
  def p(s) $stderr.puts "\033[u\033[A\033[K#{s}" end
  def n() $stderr.write "\n\033[s" end
end
$zrp = Zrp.new





def do_stops
  
  $zrp.n
  $zrp.p "Mapping stops.."

  stops = $postgres.exec("select  stop_id, stop_name, location_type, parent_station, wheelchair_boarding, platform_code, ST_AsGeoJSON(location) as geometry from gtfs.stops order by stop_name");
  stopsCount = stops.cmdtuples
  $zrp.n
  $zrp.n

  stops.each do |stop|
    node = {
      type: 'Feature',
      geometry: JSON.parse(stop['geometry']),
      properties: {
        id: "#{stop['stop_id'].downcase.gsub(/\W/,'.')}",
        title: stop['stop_name']
      }
    }
    stop.delete('geometry')
    stop["parent_station"] = stop['parent_station'].blank? ? nil : "gtfs.stops.#{stop['parent_station'].downcase.gsub(/\W/,'.')}"
    node[:properties][:data] = stop
    
    $api.create_object(node)
    
    $zrp.p "#{stopsCount}; #{stop['stop_name']}" if stopsCount % 100 == 0
    stopsCount -= 1
  end
end




def addOneRoute(route,dir)
  line = {
    type: "LineString",
    coordinates: []
  }

  r = route['route_id']

  stops = $postgres.exec("select * from stops_for_line('#{r}',#{dir})")
  shape = $postgres.exec("select * from shape_for_line('#{r}')")
  if shape.cmdtuples == 0
    shape = nil
  else
    shape.each do |s|
      line[:coordinates] << [s['lon'].to_f, s['lat'].to_f]
    end
  end

  if stops.cmdtuples > 1
    start_name = end_name = nil
    stops.each do |s|
      start_name = s['name'] if start_name.nil?
      end_name = s['name']
      if( shape.nil? )
        line[:coordinates] << [s['lon'].to_f, s['lat'].to_f]
      end
    end
    route['route_from'] = start_name
    route['route_to'] = end_name

    aname = route['agency_id'] || ''

    node = {
      type: 'Feature',
      geometry: line,
      properties: {
        id: "#{aname.gsub(/\W/,'')}.#{route['route_id'].gsub(/\W/,'')}.#{dir}".downcase,
        title: route['route_long_name']
      }
    }
    node[:properties][:data] = route
    $api.create_object(node)
  else
    $routes_rejected += 1
  end
end


def do_routes
  $zrp.n
  $zrp.p "Mapping routes.."
  $routes_rejected = 0

  routes = $postgres.exec("select * from gtfs.routes");
  totalRoutes = routes.cmdtuples

  $zrp.n
  routes.each do |route|
    $zrp.p "#{totalRoutes}; #{route['route_id']}; #{route['route_short_name']}; #{route['route_long_name']}"
    totalRoutes -= 1
    addOneRoute(route,0)
    addOneRoute(route,1)
  end

end

opts = GetoptLong.new(
  [ '--prefix', '-p', GetoptLong::REQUIRED_ARGUMENT ]
)


opts.each do |opt, arg|
  case opt
    when '--prefix'
      $prefix = arg
  end
end

$newDir =  File.expand_path(ARGV.shift)


unless File.directory?($newDir)
  puts "database data or gtfs directory missing..."
  exit 0
end

$gtfs_files.each do |f|
  if f == 'shapes' and !File.exists? "#{$newDir}/#{f}.txt"
    $gtfs_files.delete(f)
    next
  end

  if f == 'feed_info' and !File.exists? "#{$newDir}/#{f}.txt"
    $gtfs_files.delete(f)
    next
  end

  unless File.exists? "#{$newDir}/#{f}.txt"
    puts "Bad or incomplete GTFS structure in #{$newDir}."
    exit(1)
  end
end


begin
  GTFS_Import::connect
  GTFS_Import::do_log("Starting update...")

  $postgres.transaction do
    begin
      GTFS_Import::cons_calendartxt
      copy_tables
    rescue Exception => e
      $stderr.puts e.message
      $stderr.puts "\nROLLBACK (copy tables)"
      exit(1)
    end
  end

  GTFS_Import::do_log("\tCommited copy gtfs.")

  $api.batch_size = 1000
  $api.set_layer('gtfs.stops')
  $api.authenticate($EP_user,$EP_pass)

  GTFS_Import::make_clear_layers($api)

  $postgres.transaction do
    begin
      do_stops
      $api.release
      GTFS_Import::do_log("\tCommited stops.")
    rescue Exception => e
      $stderr.puts e.message
      $stderr.puts "\nROLLBACK (map stops)"
      exit(1)
    end
  end

  $api.set_layer('gtfs.routes')
  $api.authenticate($EP_user,$EP_pass)
  $postgres.transaction do
    begin
      do_routes
      $api.release
      GTFS_Import::do_log("\tCommited routes mapping.")
    rescue Exception => e
      $stderr.puts e.message
      $stderr.puts "\nROLLBACK (map routes)"
      exit(1)
    end
  end

rescue Exception => e
  puts e.message
ensure
  $postgres.close
end

