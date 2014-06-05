# encoding: UTF-8

Sequel.migration do
  up do
    $stderr.puts("Creating triggers...")

    run <<-SQL
    CREATE TRIGGER object_inserted
      AFTER INSERT OR UPDATE ON objects
      FOR EACH ROW EXECUTE PROCEDURE update_layer_bounds_from_object();
    SQL

    run <<-SQL
    CREATE TRIGGER object_data_inserted
      AFTER INSERT ON object_data
      FOR EACH ROW EXECUTE PROCEDURE update_layer_bounds_from_object_data();
    SQL

  end

  down do

    run <<-SQL
      DROP TRIGGER object_inserted ON objects;
      DROP TRIGGER object_data_inserted ON object_data;
    SQL

  end
end