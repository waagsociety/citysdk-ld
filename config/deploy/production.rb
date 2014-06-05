puts "\n\n"
puts "*** Deploying to \033[1;41mProduction Server\033[0m"
puts "\n\n"

server 'api.citysdk.waag.org', :app, :web, :primary => true
