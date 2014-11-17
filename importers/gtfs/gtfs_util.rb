require "date"
require "socket"
require 'citysdk'
include CitySDK

module GTFS_Import

  def self.get_config()
    begin
      local_ip = UDPSocket.open {|s| s.connect("123.123.123.123", 1); s.addr.last}
      if(local_ip =~ /192\.168|10\.0\.135/)
        config = JSON.parse(File.read("../../config.development.json"), {symbolize_names: true})
        $isLocal = true
        $logFile = './update.log'
      else
        config = JSON.parse(File.read('/var/www/citysdk/current/config.production.json'), {symbolize_names: true})
        $isLocal = false
        $logFile = '/var/www/citysdk/shared/importers/gtfs/update.log'
      end

      $EP_url  = config[:endpoint][:url]
      $EP_user = config[:owner][:name]
      $EP_pass = config[:owner][:password]
    
      $DB_host = config[:db][:database]
      $DB_user = config[:db][:user]
      $DB_pass = config[:db][:password]
    
      $api = nil
      $postgres = nil
    rescue Exception => e
      $stderr.puts("Error with configuration...\n#{e.message}")
      exit!(-1)
    end
  end
  
  
  def self.connect_db
    begin
      get_config() if $DB_host.nil?
      $postgres = PGconn.new('localhost', '5432', nil, nil, $DB_host, $DB_user, $DB_pass)
    rescue Exception => e
      $stderr.puts("Could not connect to database...\n#{e.message}")
      exit!(-1)
    end
  end
  

  def self.do_log(s)
    File.open($logFile,'a') do |fd|
      fd.puts "#{Time.now.strftime('%Y-%m-%d - %H:%M:%S')} -- #{s}"
    end
  end


######################### fix calendar and exceptions ##########################
  $calendar_excepts = {}
  def self.trip_does_run(s,d)
    if $calendar_excepts[s]
      $calendar_excepts[s].each do |e|
        return false if e[0] == d and e[1] == '2'
      end
    end
    true
  end

  def self.trip_does_not_run(s,d)
    if $calendar_excepts[s]
      $calendar_excepts[s].each do |e|
        return false if e[0] == d and e[1] == '1'
      end
    end
    true
  end

  def self.do_one_calendar_row(service_id,days, s, e, f)
    day = s
    end_d = e.next
    while day != end_d do
      if( days[day.wday] == '1' )
        if GTFS_Import::trip_does_run(service_id,day)
          f.puts "#{service_id},#{day.strftime('%Y%m%d')},1"
        end
      else # no service
        if !GTFS_Import::trip_does_not_run(service_id,day) # runs after all...
          f.puts "#{service_id},#{day.strftime('%Y%m%d')},1"
        end
      end
      day = day.next
    end
  end



  # consolidate calendar.txt into flat file calendar_dates.txt with just '1' exception types.
  def self.cons_calendartxt

    if File.exists? "#{$newDir}/calendar.txt" and !File.exists? "#{$newDir}/calendar_dates.txt.old"

      $zrp.p "Consolidating calendar.txt.\n"

      if File.exists? "#{$newDir}/calendar_dates.txt"

        CSV.open("#{$newDir}/calendar_dates.txt", 'r:bom|utf-8', :quote_char => '"', :col_sep =>',',:headers => true, :row_sep =>:auto) do |csv|
          csv.each do |row|
            $calendar_excepts[row['service_id']] = [] if $calendar_excepts[row['service_id']].nil?
            $calendar_excepts[row['service_id']] << [Date.parse(row['date']),row['exception_type']]
          end
        end
        system "mv #{$newDir}/calendar_dates.txt #{$newDir}/calendar_dates.txt.old"
      else
        system "touch #{$newDir}/calendar_dates.txt.old"
      end

      File.open("#{$newDir}/calendar_dates.txt",'w') do |fd|
        fd.puts "service_id,date,exception_type"

        CSV.open("#{$newDir}/calendar.txt", 'r:bom|utf-8', :quote_char => '"', :col_sep =>',',:headers => true, :row_sep =>:auto) do |csv|
          csv.each do |row|
            days = [row['sunday'],row['monday'],row['tuesday'],row['wednesday'],row['thursday'],row['friday'],row['saturday']]
            GTFS_Import::do_one_calendar_row(row['service_id'],days,Date.parse(row['start_date']),Date.parse(row['end_date']), fd)
          end
        end
      end
    end
    $calendar_excepts = {}
  end

######################### fix calendar and exceptions ##########################


# add gtfs specific sql functions
def self.add_utility_functions

  # return type of transport given the smallint GTFS route_type code
  $postgres.exec <<-SQL
      drop function if exists transport_type(t smallint);
      create function transport_type(t smallint)
          returns text
      as $$
          declare pttypes text[];
          begin
              pttypes[0] = 'Tram';
              pttypes[1] = 'Subway';
              pttypes[2] = 'Rail';
              pttypes[3] = 'Bus';
              pttypes[4] = 'Ferry';
              pttypes[5] = 'Cable car';
              pttypes[6] = 'Gondola';
              pttypes[7] = 'Funicular';
              return  pttypes[t];
          end
      $$ language plpgsql;
  SQL

  # return all routes that service a given stop_id
  # select * from rlines_for_stop('58200020')
  $postgres.exec <<-SQL
    drop function if exists rlines_for_stop(stop text);
    create function rlines_for_stop(stop text)
    returns setof gtfs.routes
    as $$
    begin
        return query select *
          from
            gtfs.routes
          where
            routes.route_id in
              (select distinct trips.route_id from gtfs.trips where trip_id in (select distinct trip_id from gtfs.stop_times where stop_id = stop));
    end
    $$ language plpgsql;
  SQL



  $postgres.exec <<-SQL
      drop function if exists line_schedule(routeid text, direction integer, day integer);
      create function line_schedule(routeid text, direction integer, day integer)
        returns table(trip_id text, stop_id text, departure_time text)
      as $$
      begin

        return query
          select gtfs.stop_times.trip_id,gtfs.stop_times.stop_id,gtfs.stop_times.departure_time
                    from gtfs.stop_times
                    where gtfs.stop_times.trip_id in
                        (select gtfs.trips.trip_id
                          from gtfs.trips
                          inner join gtfs.calendar_dates using (service_id)
                          where gtfs.trips.route_id = routeid and
                          gtfs.trips.direction_id = direction and
                          gtfs.calendar_dates.date = current_date + (day::text || ' days')::interval
                        )
          ;

      end
      $$ language plpgsql;
  SQL


  $postgres.exec <<-SQL
      drop function if exists stop_now(stopid text,tzoffset text);
      create function stop_now(stopid text,tzoffset text)
      returns table(route_id text, direction_id smallint, route_type text, route_name text , headsign text, departure text, agency_id text)
      as $$
        declare offs interval;
        declare n timestamp = now() - tzoffset::interval;
      begin
          return query select trips.route_id::text,
              trips.direction_id,
              transport_type(routes.route_type),
              routes.route_short_name::text,
              trips.trip_headsign::text,
              stop_times.departure_time::text,
              routes.agency_id::text

          from gtfs.calendar_dates,gtfs.trips, gtfs.stop_times, gtfs.routes where
              stop_times.stop_id = stopid and
              stop_times.trip_id = trips.trip_id and
              routes.route_id = trips.route_id and
              ( departs_within(stop_times.departure_time, '-5 minutes'::interval, n) or
              departs_within(stop_times.departure_time, '55 minutes'::interval, n) ) and
              trips.service_id = calendar_dates.service_id and
              calendar_dates.date = now()::date and
              calendar_dates.exception_type = 1

          order by stop_times.departure_time;
      end;
      $$ language plpgsql;
  SQL


  # return trips from the current stop for today + n days
  # select * from departs_from_stop('58200020',1) -- tomorrow
  $postgres.exec <<-SQL
      drop function if exists departs_from_stop(stopid text, days integer);
      create function departs_from_stop(stopid text, days integer)
      returns table(route_id text, direction_id smallint, route_type text, route_name text , headsign text, departure text, agency_id text)
      as $$
      begin
          return query select
              trips.route_id::text,
              trips.direction_id,
              transport_type(routes.route_type),
              routes.route_short_name::text,
              trips.trip_headsign::text,
              stop_times.departure_time::text,
              routes.agency_id::text

          from gtfs.calendar_dates,gtfs.trips, gtfs.stop_times, gtfs.routes where
              stop_times.stop_id = stopid and
              stop_times.trip_id = trips.trip_id and
              routes.route_id = trips.route_id and
              trips.service_id = calendar_dates.service_id and
              calendar_dates.date = (now() + (days::text || ' days')::interval)::date and
              calendar_dates.exception_type = 1
          order by route_id,stop_times.departure_time;
      end;
      $$ language plpgsql;
  SQL



  # return trips from the current stop for today
  # select * from departs_from_stop_today('58200020'::text)
  $postgres.exec <<-SQL
      drop function if exists departs_from_stop_today(stopid text);
      create function departs_from_stop_today(stopid text)
      returns table(route_id text, direction_id smallint, route_type text, route_name text , headsign text, departure text, agency_id text)
      as $$
      begin
          return query select * from departs_from_stop(stopid,0);
      end;
      $$ language plpgsql;
  SQL



  # return trips from the current stop within the given time interval
  # select * from departs_from_stop_within('58200020'::text, '1 hour'::interval)
  $postgres.exec <<-SQL
      drop function if exists departs_from_stop_within(stopid text, i interval);
      create function departs_from_stop_within(stopid text, i interval)
      returns table(route_id text, direction_id smallint, route_type text, route_name text , headsign text, departure text)
      as $$
          declare n timestamp = now();
      begin
          return query select trips.route_id::text,
              trips.direction_id,
              transport_type(routes.route_type),
              routes.route_short_name::text,
              trips.trip_headsign::text,
              stop_times.departure_time::text

          from gtfs.calendar_dates,gtfs.trips, gtfs.stop_times, gtfs.routes where
              stop_times.stop_id = stopid and
              stop_times.trip_id = trips.trip_id and
              routes.route_id = trips.route_id and
              departs_within(stop_times.departure_time, i, n) and
              trips.service_id = calendar_dates.service_id and
              calendar_dates.date = now()::date and
              calendar_dates.exception_type = 1

          order by stop_times.departure_time;
      end;
      $$ language plpgsql;
  SQL


  # check wether a departure_time from the stop_times table is within <interval> from now
  $postgres.exec <<-SQL
  drop function if exists departs_within(deptime text, i interval, nu timestamp);
  create function departs_within(deptime text, i interval,nu timestamp)
  returns boolean
  as $$
      declare
        dparts timestamp;
        now timestamp = now();
      begin
          dparts := (nu - localtime) + deptime::interval;
          return (dparts > now and dparts < now + i) or (dparts > now + i and dparts < now);
      end;
  $$ language plpgsql;
  SQL



  # given a route, return the trip_id of the longest trip on that route
  # select * from longest_trip_for_route('CXX|F157',1)
  # select * from longest_trip_for_route('CXX|M170',1) 4 sec!!
  $postgres.exec <<-SQL
      drop function if exists longest_trip_for_route(route text,direction integer);
      create function longest_trip_for_route(route text,direction integer)
      returns text
      as $$
          begin
              return stop_times.trip_id from gtfs.stop_times where trip_id in
                (select trip_id from gtfs.trips where route_id = route and direction_id = direction)
              group by gtfs.stop_times.trip_id
              order by count(gtfs.stop_times.stop_id) desc
              limit 1;
          end
      $$ language plpgsql;
  SQL


  # return all routes that service a given stop_id
  # select * from lines_for_stop('58200020')
  $postgres.exec <<-SQL
    drop function if exists lines_for_stop(stop text);
    create function lines_for_stop(stop text)
    returns table(route_id text, name text, agency text, type text)
    as $$
      begin
        return query select routes.route_id::text,
               route_short_name::text,
               agency_id::text,
               transport_type(route_type)
          from
            gtfs.routes
          where
            routes.route_id in
              (select distinct trips.route_id from gtfs.trips where trip_id in (select distinct trip_id from gtfs.stop_times where stop_id = stop));
      end
    $$ language plpgsql;
  SQL




  # return all stops that service a given route_id and a direction code
  # select * from stops_for_line('CXX|F157',1)
  $postgres.exec <<-SQL
      drop function if exists stops_for_line(text,integer);
      create function stops_for_line(text,integer)
      returns table(name text, lon float, lat float, stop_id text, stop_seq smallint)
      as $$
          select distinct stops.stop_name as name,
                          st_x(stops.location) as lon,
                          st_y(stops.location) as lat,
                          stops.stop_id,
                          stop_sequence
                    from gtfs.stop_times left join gtfs.stops on stops.stop_id = stop_times.stop_id
                    where trip_id = (select longest_trip_for_route($1,$2))
                    order by stop_sequence;
      $$ language sql;
  SQL

  $postgres.exec <<-SQL
    drop function if exists shape_for_line(line text);
    create function shape_for_line(line text)
      returns table(lon float, lat float, seq integer)
      as $$
      declare tripid text;
      begin
          select longest_trip_for_route(line,1) into tripid;

          return query
              select shape_pt_lon::float, shape_pt_lat::float,
                     shape_pt_sequence as seq
                     from gtfs.shapes
                     where shape_id = (select shape_id from gtfs.trips where trip_id = tripid limit 1)
                     order by seq;
      end
      $$ language plpgsql;
  SQL

end



end
