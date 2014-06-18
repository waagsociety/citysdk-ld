# encoding: UTF-8

Sequel.migration do
  up do

    $stderr.puts('Creating functions...')

    # Returns object id from cdk_id
    run <<-SQL
    CREATE OR REPLACE FUNCTION cdk_id_to_internal(_cdk_id text)
      RETURNS bigint
      AS $$
        DECLARE
          _id bigint;
        BEGIN
          SELECT id INTO _id FROM objects
          WHERE _cdk_id = cdk_id;
          IF _id IS NULL THEN
            RAISE EXCEPTION 'Object not found: ''%''', _cdk_id;
          END IF;
          RETURN _id;
      END $$ LANGUAGE plpgsql IMMUTABLE;
    SQL

    run <<-SQL
    CREATE FUNCTION update_layer_bounds(layer_id integer) RETURNS void
    AS $$
        DECLARE object_data_bounds geometry;
        DECLARE object_bounds geometry;
        BEGIN
          object_data_bounds := (
            SELECT ST_SetSRID(ST_Extent(geom)::geometry, 4326) FROM objects
            JOIN object_data ON objects.id = object_data.object_id
              AND object_data.layer_id = layer_id
          );

          object_bounds := (
            SELECT ST_SetSRID(ST_Extent(geom)::geometry, 4326) FROM objects
              WHERE layer_id = layer
          );

          UPDATE layers SET geom = ST_Envelope(ST_Collect(object_data_bounds, object_bounds)) WHERE id = layer_id;
        END;
    $$ language plpgsql;

    CREATE FUNCTION update_layer_bounds_from_object() RETURNS TRIGGER
    AS $$
        DECLARE
          layer_id integer := NEW.layer_id;
          box geometry := (SELECT geom FROM layers WHERE id = NEW.layer_id);
        BEGIN
          IF box IS NULL THEN
            UPDATE layers SET geom = ST_Envelope(ST_Buffer(ST_SetSRID(NEW.geom,4326), 0.0000001) ) WHERE id = layer_id;
          ELSE
            UPDATE layers SET geom = ST_Envelope(ST_Collect(NEW.geom, box)) WHERE id = layer_id;
          END IF;
          RETURN NULL;
        END;
    $$ language plpgsql;

    CREATE FUNCTION update_layer_bounds_from_object_data() RETURNS TRIGGER
    AS $$
        DECLARE
          layer_id integer := NEW.layer_id;
          box geometry := (SELECT geom FROM layers WHERE id = NEW.layer_id);
          geo geometry := (SELECT geom FROM objects WHERE id = NEW.object_id);
        begin
          IF box IS NULL THEN
            UPDATE layers SET geom = ST_Envelope(ST_Buffer(ST_SetSRID(geo, 4326), 0.0000001)) WHERE id = layer_id;
          ELSE
            UPDATE layers SET geom = ST_Envelope(ST_Collect(geo, box)) WHERE id = layer_id;
          END IF;
          RETURN NULL;
        END;
    $$ language plpgsql;
    SQL


  end

  down do

    run <<-SQL
      DROP FUNCTION IF EXISTS cdk_id_to_internal(_cdk_id text) CASCADE;
      DROP FUNCTION IF EXISTS update_layer_bounds(layer integer) CASCADE;
      DROP FUNCTION IF EXISTS update_layer_bounds_from_object() CASCADE;
      DROP FUNCTION IF EXISTS update_layer_bounds_from_object_data() CASCADE;
    SQL

  end
end
