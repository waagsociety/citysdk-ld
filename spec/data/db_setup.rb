system "psql postgres -c 'drop database if exists \"citysdk-test\"'"
system "createdb \"citysdk-test\""
system "psql \"citysdk-test\" -c 'create extension hstore'"
system "psql \"citysdk-test\" -c 'create extension postgis'"
system 'cd db && ruby run_migrations.rb test'
