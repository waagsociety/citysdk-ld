puts "\n\n"
puts "*** Deploying to \033[1;41mTest Server\033[0m"
puts "\n\n"

server 'test-api.citysdk.waag.org', :app, :web, :primary => true
