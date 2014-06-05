#!/usr/bin/env ruby
require "pg"
require "csv"
require "json"
require 'socket'
require 'tempfile'
require 'getoptlong'
require './gtfs_util.rb'
require './gtfs_funcs.rb'



local_ip = UDPSocket.open {|s| s.connect("123.123.123.123", 1); s.addr.last}
if(local_ip =~ /192\.168|10\.0\.135/)
  dbconf = JSON.parse(File.read('../../config.json'), {symbolize_names: true})
else
  dbconf = JSON.parse(File.read('/var/www/citysdk/current/config.json'), {symbolize_names: true})
end

$DB_name = dbconf[:db][:database]
$DB_user = dbconf[:db][:user]
$DB_pass = dbconf[:db][:password]
$newDir = ''
$pg_csdk = nil
$prefix = ''
$quote = '"'


$gtfs_files = ['agency', 'feed_info', 'calendar_dates', 'stops', 'routes', 'trips', 'stop_times','shapes']

def create_schema
  $pg_csdk.exec("drop schema if exists igtfs cascade; create schema igtfs;")
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


  $pg_csdk.exec "drop index if exists calendar_dates_service_id;"


  $pg_csdk.exec <<-SQL
    insert into gtfs.calendar_dates select
      ('#{$prefix}' || service_id), date, exception_type
    from igtfs.calendar_dates;
  SQL

  $pg_csdk.exec "create table calendar_dates as select distinct * from gtfs.calendar_dates;"
  $pg_csdk.exec "drop table gtfs.calendar_dates;"
  $pg_csdk.exec "alter table calendar_dates set schema gtfs;"
  $pg_csdk.exec "create index calendar_dates_service_id on gtfs.calendar_dates(service_id);"

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


  $pg_csdk.exec "alter table igtfs.stops add column location geometry(point,4326)"
  $pg_csdk.exec "update igtfs.stops set (stop_id,location) = ('#{$prefix}' || stop_id, ST_SetSRID(ST_Point(stop_lon,stop_lat),4326))"
  $pg_csdk.exec "update igtfs.stops set parent_station = '' where parent_station is NULL" if cls.include?('parent_station')
  $pg_csdk.exec "update igtfs.stops set wheelchair_boarding = 0 where wheelchair_boarding is NULL" if cls.include?('wheelchair_boarding')
  $pg_csdk.exec "update igtfs.stops set platform_code = '' where platform_code is NULL" if cls.include?('platform_code')
  $pg_csdk.exec "update igtfs.stops set location_type = 0 where location_type is NULL" if cls.include?('location_type')

  $pg_csdk.exec <<-SQL
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

    $pg_csdk.exec <<-SQL
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
    $pg_csdk.exec <<-SQL
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
    a = $pg_csdk.escape(a.join(', '))

    select = "feed_publisher_name,feed_publisher_url,feed_lang,feed_start_date,feed_end_date,feed_version,'#{a}','#{Time.now.strftime('%Y-%m-%d')}'"
    select.gsub!('feed_end_date','feed_valid_to') if cls.include?('feed_valid_to')
    select.gsub!('feed_start_date','feed_valid_from') if cls.include?('feed_valid_from')

    $pg_csdk.exec <<-SQL
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

  $pg_csdk.exec "update igtfs.routes set (route_id) = ('#{$prefix}' || route_id)"

  $pg_csdk.exec "update igtfs.routes set route_short_name = route_long_name where route_short_name is NULL"

  $pg_csdk.exec <<-SQL
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

  $pg_csdk.exec "drop index if exists gtfs.stop_times_trip_id;"
  $pg_csdk.exec "drop index if exists gtfs.stop_times_stop_id;"
  $pg_csdk.exec "drop index if exists gtfs.stop_times_departure_time;"
  $pg_csdk.exec "drop index if exists gtfs.stop_times_stop_id_trip_id;"

  select = "'#{$prefix}' || trip_id, arrival_time, departure_time, '#{$prefix}' || stop_id, stop_sequence, stop_headsign, pickup_type, drop_off_type"
  select.gsub!('stop_headsign',"''") if !cls.include?('stop_headsign')
  select.gsub!('pickup_type','0') if !cls.include?('pickup_type')
  select.gsub!('drop_off_type','0') if !cls.include?('drop_off_type')

  $zrp.p "Merging stop_times.."
  $pg_csdk.exec <<-SQL
    insert into gtfs.stop_times select
      #{select}
    from igtfs.stop_times where igtfs.stop_times.departure_time != '';
  SQL

  $pg_csdk.exec "create table stop_times as select distinct * from gtfs.stop_times;"
  $pg_csdk.exec "drop table gtfs.stop_times;"
  $pg_csdk.exec "alter table stop_times set schema gtfs;"


  $zrp.p "Create index stop_times(stop_id,trip_id).."
  $pg_csdk.exec "create index stop_times_stop_id_trip_id on gtfs.stop_times using btree(trip_id, stop_id);"
  $zrp.p "Create index stop_times(trip_id).."
  $pg_csdk.exec "create index stop_times_trip_id on gtfs.stop_times(trip_id);"
  $zrp.p "Create index stop_times(stop_id).."
  $pg_csdk.exec "create index stop_times_stop_id on gtfs.stop_times(stop_id);"
  $zrp.p "Create index stop_times(departure_time).."
  $pg_csdk.exec "create index stop_times_departure_time on gtfs.stop_times(departure_time);"

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

    $pg_csdk.exec "update igtfs.trips set direction_id = 0 where direction_id is NULL" if cls.include?('direction_id')

    $zrp.p "Merging trips.."

    $pg_csdk.exec <<-SQL
      insert into gtfs.trips select
        #{select}
      from igtfs.trips;
    SQL

    $pg_csdk.exec "create table trips as select distinct * from gtfs.trips;"
    $pg_csdk.exec "drop table gtfs.trips;"
    $pg_csdk.exec "alter table trips set schema gtfs;"
    $pg_csdk.exec "create index trips_trip_id on gtfs.trips(trip_id);"
    $pg_csdk.exec "create index trips_route_id on gtfs.trips(route_id);"
    $pg_csdk.exec "create index trips_direction_id on gtfs.trips(direction_id);"

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
    $pg_csdk.exec "create table igtfs.#{f} (#{ca.join(',')})"
    $pg_csdk.exec "copy igtfs.#{f} from '#{$newDir}/#{f}.txt' QUOTE '#{$quote}' CSV HEADER"
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


  stops_a = []

  CSV.open("#{$newDir}/stops.txt", 'r:bom|utf-8', :quote_char => '"', :col_sep =>',',:headers => true, :row_sep =>:auto) do |csv|
    csv.each do |row|
      s = $prefix + row['stop_id']
      stops_a << "'#{s}'"
    end
  end



  stops = $pg_csdk.exec("select * from gtfs.stops where stop_id in (#{stops_a.join(',')}) order by stop_name");
  stopsCount = stops.cmdtuples
  $zrp.n
  $zrp.n

  stops.each do |stop|
    nid = GTFS_Import::stopObject(stop)

    if nid
      GTFS_Import::stopObjectData(nid, stop)
    end
    $zrp.p "#{stopsCount}; #{stop['stop_name']}" if stopsCount % 100 == 0
    stopsCount -= 1
  end


end

def do_routes

  $zrp.n
  $zrp.p "Mapping routes.."

  @val=nil

  if $gtfs_files.include?('feed_info')

    File.open("#{$newDir}/feed_info.txt", 'r:bom|utf-8') do |f|
      h = f.gets.chomp.split(',') #headers
      sd = h.index('feed_start_date') || h.index('feed_valid_from')
      ed = h.index('feed_end_date') || h.index('feed_valid_to')
      if( sd && ed)
        s = f.gets.chomp.split(',')
        sd = s[sd] + " 00:00"
        ed = s[ed] + " 23:59"
        @val = "[#{sd},#{ed}]"
      end
    end
  end

  $routes_rejected = 0

  route_a = []

  CSV.open("#{$newDir}/routes.txt", 'r:bom|utf-8', :quote_char => '"', :col_sep =>',',:headers => true, :row_sep =>:auto) do |csv|
    csv.each do |row|
      r = $prefix + row['route_id']
      route_a << "'#{r}'"
    end
  end

  routes = $pg_csdk.exec("select * from gtfs.routes where route_id in (#{route_a.join(',')})");


  totalRoutes = routes.cmdtuples

  $zrp.n
  routes.each do |route|
    $zrp.p "#{totalRoutes}; #{route['route_id']}; #{route['route_short_name']}; #{route['route_long_name']}"
    totalRoutes -= 1
    GTFS_Import::addOneRoute(route,0,@val)
    GTFS_Import::addOneRoute(route,1,@val)
  end

end



def do_cleanup

  $zrp.n
  $zrp.p "Cleaning up.."

  $zrp.p "Collecting old trips.."

  $pg_csdk.exec <<-SQL
    select trip_id,service_id into temporary cu_tripids from gtfs.trips where
      service_id in (
        select distinct service_id from gtfs.calendar_dates where date <= (now() - '2 days'::interval)
      );
  SQL

  $zrp.p "Removing still valid trips from collection.."
  $pg_csdk.exec <<-SQL
    delete from  cu_tripids where
      service_id in (
       select distinct service_id from gtfs.calendar_dates where date > (now() - '2 days'::interval)
      );
  SQL

  $zrp.p "Deleting old stoptimes.."
  $pg_csdk.exec <<-SQL
    delete from gtfs.stop_times where trip_id in
      ( select distinct trip_id from cu_tripids );
  SQL

  $zrp.p "Deleting obsolete trips.."
  $pg_csdk.exec <<-SQL
    delete from gtfs.trips where trip_id in
      ( select distinct trip_id from cu_tripids );
  SQL

  $zrp.p "Deleting old calendar date entries.."
  $pg_csdk.exec <<-SQL
    delete from gtfs.calendar_dates where date <= (now() - '2 days'::interval);
  SQL

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


unless File.directory?($newDir) && $DB_name && $DB_pass && $DB_user
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
  $pg_csdk = PGconn.new('localhost', '5432', nil, nil, $DB_name, $DB_user, $DB_pass)

  GTFS_Import::get_layer_ids()

  GTFS_Import::do_log("Starting update: prefix: #{$prefix}")

  $pg_csdk.transaction do
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

  $pg_csdk.transaction do
    begin
      do_cleanup
    rescue Exception => e
      $stderr.puts e.message
      $stderr.puts "\nROLLBACK (cleanup)"
      exit(1)
    end
  end

  GTFS_Import::do_log("\tCommited cleanup.")

  $pg_csdk.transaction do
    begin
      do_stops
      do_routes
    rescue Exception => e
      $stderr.puts e.message
      $stderr.puts "\nROLLBACK (map stops & routes)"
      exit(1)
    end
  end

  GTFS_Import::do_log("\tCommited stops and routes mapping.")

  $stderr.puts "\nCOMMIT"

rescue Exception => e
  puts e.message
ensure
  $pg_csdk.close
end

