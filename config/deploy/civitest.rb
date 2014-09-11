puts "\n\n"
puts "*** Deploying to \033[1;41mCivity Test Server\033[0m"
puts "\n\n"

server '62.177.253.29', :app, :web, :primary => true
