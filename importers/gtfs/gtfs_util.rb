require "date"
require "socket"

module GTFS_Import

  RevMods = {
    '0' => 'tram',
    '1' => 'subway',
    '2' => 'rail',
    '3' => 'bus',
    '4' => 'ferry',
    '5' => 'cable car',
    '6' => 'gondola',
    '7' => 'funicular'
  }

  Modalities = {
    'Tram'  => 0,
    'Subway'  => 1,
    'Rail'  => 2,
    'Bus'  => 3,
    'Ferry'  => 4,
    'Cable car'  => 5,
    'Gondola'  => 6,
    'Funicular'  => 7
  }


  local_ip = UDPSocket.open {|s| s.connect("123.123.123.123", 1); s.addr.last}
  if(local_ip =~ /192\.168|10\.0\.135/)
    $isLocal = true
    $logFile = './update.log'
  else
    $isLocal = false
    $logFile = '/var/www/citysdk/shared/importers/gtfs/update.log'
  end

  def self.do_log(s)
    File.open($logFile,'a') do |fd|
      fd.puts "#{Time.now.strftime('%Y-%m-%d - %H:%M:%S')} -- #{s}"
    end
  end



  $calendar_excepts = {}

  def self.does_run(s,d)
    if $calendar_excepts[s]
      $calendar_excepts[s].each do |e|
        return false if e[0] == d and e[1] == '2'
      end
    end
    true
  end

  def self.does_not_run(s,d)
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
        if GTFS_Import::does_run(service_id,day)
          f.puts "#{service_id},#{day.strftime('%Y%m%d')},1"
        end
      else # no service
        if !GTFS_Import::does_not_run(service_id,day) # runs after all...
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


  def self.makeCDKID(s)
    Digest::MD5.hexdigest(s).to_i(16).base62_encode
  end

  # TODO: use Sequel's to_hstore
  class ::Hash
    def to_hstore(pg_connection)
      pairs = []
      data =  "hstore(ARRAY["
      self.each_pair do |p|
        pairs << "['#{pg_connection.escape(p[0].to_s)}','#{pg_connection.escape(p[1].to_s)}']"
      end
      data += pairs.join(',')
      data += "])"
      data
    end
  end


  def self.modalitiesForStop(s)
    mods = []
    stop_id = s['stop_id']
    lines = $pg_csdk.exec("select * from lines_for_stop('#{stop_id}')")
    lines.each do |l|
      m = Modalities[l['type']] || 200
      mods << m if !mods.include?(m)
    end
    mods.to_s.gsub('[','{').gsub(']','}')
  end



  @@agency_names = {}
  def self.get_agency_name(id)
    return @@agency_names[id] if(@@agency_names[id])
    res = $pg_csdk.exec("select agency_name from gtfs.agency where agency_id = '#{id}'")
    if( res.cmd_tuples > 0)
      @@agency_names[id] = res[0]['agency_name']
      return @@agency_names[id]
    end
    id
  end


  def self.routeObject(route,members,line,dir)
    aname = route['agency_id']
    if aname && aname == ''
      aname = $prefix
    end
    cdkid = "gtfs.line.#{aname.gsub(/\W/,'')}.#{route['route_id'].gsub(/\W/,'')}.#{dir}".downcase
    line = 'ARRAY[' + line.join(',') + "]"
    members = "{" + members.join(',') + "}"

    name = $pg_csdk.escape("#{aname} #{RevMods[route['route_type']]} #{route['route_short_name']}")

    res = $pg_csdk.exec("select id from objects where cdk_id = '#{cdkid}'")
    if( res.cmd_tuples > 0)
      id = res[0]['id']
      # update
      queri = "update objects set title='#{name}', geom=ST_MakeLine(#{line}), members='#{members}' where id=#{id}"
    else
      # insert
      id = $pg_csdk.exec("select nextval('nodes1_id_seq')")[0]['nextval'].to_i
      queri = "insert into objects (id,title,cdk_id,layer_id,node_type,members,geom) VALUES (#{id},'#{name}','#{cdkid}',#{$gtfs_lines}, 3, '#{members}', ST_MakeLine(#{line}));"
    end

    begin
      r = $pg_csdk.exec(queri)
    rescue Exception => e
      puts "routeObject: #{e.message}"
      puts queri
      return nil
    end
    if( r.result_status == 1)
      return id
    end
    puts "routeObject returns nil"
    return nil
  end



  def self.route_node_data(node_id, route)
    # {"route_id"=>"ARR|17186", "agency_id"=>"ARR", "route_short_name"=>"186", "route_long_name"=>"Oegstgeest - Gouda via Leiden", "route_type"=>"3"}
    res = $pg_csdk.exec("select id from object_data where object_id = #{node_id} and layer_id = #{$gtfs_lines}")
    if( res.cmd_tuples > 0)
      id = res[0]['id']
      queri  = "update object_data set"
      queri += " data=#{route.to_hstore($pg_csdk)}"
      queri += ", modalities='#{mods}'"
      queri += ", validity='#{val}'" if val
      queri += " where id=#{id}"
    else
      id = $pg_csdk.exec("select nextval('node_data_id_seq')")[0]['nextval'].to_i
      queri =  "insert into object_data (id,object_id,layer_id,data) "
      queri += "VALUES (#{id},'#{node_id}',#{$gtfs_lines}, #{route.to_hstore($pg_csdk)});"
    end

    begin
      r = $pg_csdk.exec(queri)
    rescue Exception => e
      puts "createNewroute_node_data: #{e.message}"
      puts queri
      exit(1)
    end
    if( r.result_status == 1)
      return id
    end
    return nil
  end

  def self.addOneRoute(route,dir)
    r = route['route_id']
    # puts "select * from stops_for_line('#{r}',#{dir})"

    stops = $pg_csdk.exec("select * from stops_for_line('#{r}',#{dir})")
    # puts "done.."
    shape = $pg_csdk.exec("select * from shape_for_line('#{r}')")
    shape = nil if shape.cmdtuples == 0

    if stops.cmdtuples > 1
      members = []
      line = []
      q = ''
      start_name = end_name = nil
      stops.each do |s|
        stop_id = s['stop_id']
        next if stop_id.nil? or stop_id==''
        nd = %{ (object_data.data @> '"stop_id"=>"#{stop_id}"') }
        begin
          q = "select * from object_data where layer_id = #{$gtfs_stops} and #{nd} limit 1"
          nd = $pg_csdk.exec(q)
          if(nd)
            nd.each do |n|
              start_name = s['name'] if start_name.nil?
              end_name = s['name']
              members << n['object_id']
              if( shape.nil? )
                line << "'" + $pg_csdk.exec("select geom from objects where id = #{n['object_id'].to_i} limit 1" )[0]['geom'] + "'::geometry"
              end
            end
          end
        rescue Exception => e
          puts "addOneRoute: #{e.message}"
          puts q
          exit(1)
        end
      end

      if( members.length > 0)
        begin
          if(shape)
            shape.each do |s|
              g = s['geom']
              line << "'#{g}'"
            end
          end
          route['route_from'] = start_name
          route['route_to'] = end_name

          id = GTFS_Import::routeObject(route,members,line,dir)
          if(id)
            GTFS_Import::route_node_data(id,route)
          end
        rescue
          return 0
        end
        return 1
      end
    else
    end
    $routes_rejected += 1
    return 0
  end


end
