# encoding: UTF-8

Sequel.migration do
  up do
    $stderr.puts('Creating schemas...')

    run <<-SQL
      DROP SCHEMA IF EXISTS gtfs CASCADE;
      CREATE SCHEMA gtfs;
    SQL

  end

  down do

    run <<-SQL
      DROP SCHEMA IF EXISTS gtfs CASCADE;
    SQL

  end
end

