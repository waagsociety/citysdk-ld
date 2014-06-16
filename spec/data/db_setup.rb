system "psql postgres -c 'DROP DATABASE IF EXISTS \"citysdk-test\"'"
system "createdb \"citysdk-test\""
system "psql \"citysdk-test\" -c 'CREATE EXTENSION hstore'"
system "psql \"citysdk-test\" -c 'CREATE EXTENSION postgis'"
system 'cd db && ruby run_migrations.rb test'
