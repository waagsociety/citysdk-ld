require 'date'
require 'json'
require 'yaml'
require './gtfs_util.rb'

@feeds = nil
@dlds = []
@yamlFile = 'feed_dlds.yaml'

Feeds = [
  ['ovapi.','http://gtfs.ovapi.nl/new/gtfs-nl.zip', '2010-01-01']
]

def do_one_feed(feed)
  $stderr.puts "Updating: #{feed[0]}\n\n"
  begin
    system "mkdir -p /tmp/cdk_gtfs"
    system "rm -rf /tmp/cdk_gtfs/*"
    system "wget -O /tmp/cdk_gtfs/gtfs.zip '#{feed[1]}'"
    system "unzip /tmp/cdk_gtfs/gtfs.zip -d /tmp/cdk_gtfs"
    system "ruby ./import.rb /tmp/cdk_gtfs"
    return true
  rescue Exception => e
    $stderr.puts e.message
  end
  false
end

GTFS_Import::do_log('Checking for updates..')

@feeds = YAML.load_file(@yamlFile) if File.exists?(@yamlFile)
@feeds = Feeds if(@feeds.nil?)

@feeds.each do |a|
  lm = `curl --silent --head #{a[1]} | grep Last-Modified`
  if lm =~ /.*,\s+(.*)\s+\d\d:/
    GTFS_Import::do_log(" #{a[0]} last: #{a[2]}; current: #{$1}")
    if Date.parse($1) > Date.parse(a[2])
      nd = $1
      a[2] = nd if do_one_feed(a)
    end
  end
end


File.open(@yamlFile,'w') do |f|
  f.write(@feeds.to_yaml)
end


