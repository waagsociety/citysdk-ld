# encoding: UTF-8

class CDKObject < Sequel::Model(:objects)
  one_to_many :object_data

  def get_layer(n)
    if n.is_a?(String)
      self.object_data.each do |nd|
        return nd if nd.layer.name == n
      end
    else
      self.object_data.each do |nd|
        return nd if nd.layer_id == n
      end
    end
    nil
  end

  def self.get_dataset(query)

    geom = true
    if query[:params][:geom] and query[:params][:geom].to_bool == false
      geom = false
    end

    columns = (self.dataset.columns - [:geom]).map { |column| "objects__#{column}".to_sym }
    if geom
      geom_function = query[:format] == :turtle ? :ST_AsText : :ST_AsGeoJSON
      geom_columns = Sequel.function(geom_function, :geom).as(:geom)
      self.dataset
          .select{columns}
          .select_append(geom_columns)
    else
      self.dataset
          .select{columns}
    end
  end

  def self.execute_write(query)
    # POST data is GeoJSON Feature or FeatureCollection,
    # with Features of following form:
    #
    # {
    #   type: "Feature",
    #   properties: {
    #     cdk_id: "n355897589",
    #     name: "De Brakke Grond",
    #     data: {
    #       amenity: "theatre",
    #       website: "http://www.brakkegrond.nl"
    #     }
    #   },
    #   geometry: {
    #     type: "Point",
    #     coordinates: [4.89396, 52.371127]
    #   }
    # }
    #
    # The data object may directly contain the object's layer data
    # (as the example above shows), or contain the data inside a
    # [layer][:layer] object, the same as API GeoJSON output.

    # Layer must exist
    layer_id = nil
    if query[:params][:layer]
      layer_id = CDKLayer.id_from_name(query[:params][:layer])
      query[:api].error!("Layer not found: '#{query[:params][:layer]}'", 404) unless layer_id
    else
      object = CDKObject.where(cdk_id: query[:params][:cdk_id]).first
      layer_id = object[:layer_id]
    end

    CDKOwner.verify_owner_for_layer(query, layer_id)

    unless ["Feature", "FeatureCollection"].include? query[:data]["type"]
      query[:api].error!("POST data must be GeoJSON Feature or FeatureCollection", 422)
    end

    results = []
    objects = []
    object_data = []

    features = case query[:data]["type"]
        when "Feature"
          [query[:data]]
        else
          query[:data]["features"]
        end

    query[:api].error!("Request should contain single Feature", 422) if query[:params][:cdk_id] and features.length > 1

    features.each do |feature|
      properties = {}
      properties = feature['properties'] if feature['properties']

      if !properties
        if query[:method] == :post
          query[:api].error!("Object without 'properties' encountered", 422)
        end
      elsif !properties['data'] && !properties['layers']
        # Objects in PATCH requests do not have to have data, but objects in POST requests do.
        if query[:method] == :post
          query[:api].error!("Object without data encountered", 422)
        end
      elsif properties['data'] && properties['layers']
        query[:api].error!("Object data must be in 'data' object, or in nested 'layers' object - not both", 422)
      elsif properties['layer']
        query[:api].error!("Object's layer cannot be set or changed with POST data", 422)
      elsif not (properties.keys - ['cdk_id', 'id', 'data', 'layers', 'title']).empty?
        msg = properties['cdk_id'] ? "cdk_id = '#{properties['cdk_id']}'" : "id = '#{properties['id']}'"
        query[:api].error!("Incorrect keys found for object with #{msg}", 422)
      end

      cdk_id = nil
      if properties['id']
        # Only accepts new objects - objects with 'id' property
        # for POST requests
        query[:api].error!("All objects must have 'cdk_id' property", 422) if query[:method] == :patch

        unless feature['geometry'] or feature['members']
          query[:api].error!("New object without geometry encountered", 422)
        end

        cdk_id = CitySDKLD.cdk_id_from_id query[:params][:layer], properties['id']

        objects << {
          id: properties['id'],
          cdk_id: cdk_id,
          db_hash: db_hash_from_geojson(query, cdk_id, layer_id, feature)
        }

        results << {
          id: properties['id'],
          cdk_id: cdk_id
        }
      elsif properties['cdk_id'] or query[:params][:cdk_id]

        if properties['cdk_id'] and query[:params][:cdk_id]
          if properties['cdk_id'] != query[:params][:cdk_id]
            query[:api].error!("URL parameter 'cdk_id' and Feature's 'cdk_id' are both present, but not the same", 422)
          end
        end

        cdk_id = nil
        if properties['cdk_id']
          cdk_id = properties['cdk_id']
        else
          cdk_id = query[:params][:cdk_id]
        end

        if query[:method] == :patch
          objects << {
            cdk_id: cdk_id,
            db_hash: db_hash_from_geojson(query, cdk_id, layer_id, feature)
          }
        end

        results << {
          cdk_id: cdk_id
        }
      else
        case query[:method]
        when :post
          query[:api].error!("All objects must either have 'id' or 'cdk_id' property", 422)
        when :patch
          query[:api].error!("All objects must have 'cdk_id' property", 422)
        end
      end
      if feature['properties'] and (feature['properties']['data'] or feature['properties']['layers'])
        object_data << {
          cdk_id: cdk_id,
          db_hash: CDKObjectDatum.db_hash_from_geojson(query, cdk_id, layer_id, feature)
        }
      end
    end

    Sequel::Model.db.transaction do
      case query[:method]
      when :post
        CDKObject.multi_insert(objects.map { |o| o[:db_hash] })
        CDKObjectDatum.multi_insert(object_data.map { |o| o[:db_hash] })

        # New objects are inserted, so new layer bounding box is computed by DB trigger
        # New bounding boxs needs to be loaded in memcached cache:
        CDKLayer.update_layer_hash layer_id
      when :patch

        update_layer_hash = false
        objects.each do |object|
          update_hash = {}
          update_hash[:title] = object[:db_hash][:title] if object[:db_hash][:title]
          if object[:db_hash][:geom]
            update_layer_hash = true
            update_hash[:geom] = object[:db_hash][:geom]
          end

          if update_hash.keys.length > 0
            db_count = CDKObject
                .where(cdk_id: object[:cdk_id])
                .update(update_hash)

            if db_count == 0
              cdk_id_exists = CDKObject.select(:cdk_id).where(id: object[:cdk_id]).count > 0
              query[:api].error!("Object not found: '#{object[:cdk_id]}'", 404) unless cdk_id_exists
            end
          end
        end

        object_data.each do |object_datum|
          if object_datum[:db_hash][:data]
            db_count = CDKObjectDatum
                .where(object_id: object_datum[:db_hash][:object_id], layer_id: object_datum[:db_hash][:layer_id])
                .update(data: object_datum[:db_hash][:data])

            # if no records were updated, something went wrong
            if db_count == 0
              cdk_id_exists = CDKObject.select(:cdk_id).where(id: object_datum[:db_hash][:object_id]).count > 0
              query[:api].error!("Object not found: '#{object_datum[:cdk_id]}'", 404) unless cdk_id_exists
              query[:api].error!("No data found for on layer '#{query[:params][:layer]}' for object '#{object_datum[:cdk_id]}'", 404)
            end
          end
        end

        # Only update layer hashes if object geometries were changed
        if update_layer_hash
          CDKLayer.update_layer_hash layer_id
        end

      end
    end

    results
  end


  def self.execute_delete_from_layer(query)
    # delete all objects from a single layer
    layer_id = CDKLayer.id_from_name(query[:params][:layer])
    query[:api].error!("Layer not found: '#{query[:params][:layer]}'", 404) unless layer_id

    Sequel::Model.db.transaction do
      # delete object data:
      CDKObjectDatum.where(layer_id: layer_id).delete
      # delete objects:
      # TO DO fix objects where data from other layers!!
      CDKObject.where(layer_id: layer_id).delete

      # move_object = <<-SQL
      #   UPDATE objects SET layer_id = -1
      #   FROM object_data
      #   WHERE object_id = objects.id AND
      #     object_data.layer_id != #{layer_id} AND
      #     objects.layer_id != -1
      # SQL

    end
  end

  def self.execute_delete(query)

    # delete all objects from a single layer
    return execute_delete_from_layer(query) if query[:path][0] == :layers

    # If object has data on other layers:
    #   Delete data and move object itself to layer -1
    # If object has only data on its own layer:
    #   Delete object and data
    #
    # See layer.rb > execute_delete for example

    object = CDKObject.where(cdk_id: query[:params][:cdk_id]).first
    query[:api].error!("Object not found: '#{query[:params][:cdk_id]}'", 404) unless object

    CDKOwner.verify_owner_for_layer(query, object[:layer_id])

    # TODO: create SQL function in 003_functions migration
    move_object = <<-SQL
      UPDATE objects SET layer_id = -1
      FROM object_data
      WHERE object_id = objects.id AND
        object_data.layer_id != objects.layer_id AND
        objects.layer_id != -1 AND
        objects.cdk_id = ?
    SQL

    Sequel::Model.db.transaction do
      # First, get object_id of object data to be deleted:
      object_datum = CDKObjectDatum
          .where(object_id: CDKObject.select(:id).where(cdk_id: query[:params][:cdk_id]))
          .where(layer_id: CDKObject.select(:layer_id).where(cdk_id: query[:params][:cdk_id]))
          .select(:id)
          .first

      query[:api].error!(
        "Object can only be deleted using this API call when object has data on" +
      " same layer as object is on. Use '/objects/:cdk_id/layers/:layer' instead.", 422
      ) unless object_datum

      # Then, move object to layer 'none' if object has data on other layers:
      Sequel::Model.db.fetch(move_object, query[:params][:cdk_id]).all

      # Finally, delete object data and delete possible orphans:
      CDKObjectDatum.where(id: object_datum[:id]).delete
      CDKObject.delete_orphans
    end
  end

  def self.delete_orphans
    # TODO: consider creating trigger on object_data delete.
    sql = <<-SQL
      DELETE FROM objects
      WHERE layer_id = -1 AND
        NOT EXISTS (
          SELECT TRUE
          FROM object_data
          WHERE object_id = objects.id
        );
    SQL

    Sequel::Model.db.fetch(sql).all
  end

  def self.db_hash_from_geojson(query, cdk_id, layer_id, feature)
    db_hash = {
      cdk_id: cdk_id,
      layer_id: layer_id
    }

    if feature['crs'] and
       feature['crs']['type'] == 'EPSG' and
       feature['crs']['properties']['code'] != 4326

      if feature['geometry']
        set_srid = Sequel.function(:ST_SetSRID, Sequel.function(:ST_GeomFromGeoJSON, feature['geometry'].to_json), feature['crs']['properties']['code'])
        force_rhr = Sequel.function(:ST_ForceRHR, set_srid)
        db_hash[:geom] = Sequel.function(:ST_Transform, force_rhr, 4326)
      end
    else
      if feature['geometry']
        db_hash[:geom] = Sequel.function(:ST_SetSRID, Sequel.function(:ST_GeomFromGeoJSON, feature['geometry'].to_json), 4326)
      end
    end
    db_hash[:title] = feature['properties']['title'] if feature['properties'] and feature['properties']['title']
    db_hash
  end

  def self.make_hash(h)
    h[:layer] = CDKLayer.name_from_id(h[:layer_id])
    h[:title] = '' if h[:title].nil?

    h.delete(:layer_id)
    h.delete(:id)
    h.delete(:members)

    h.delete(:created_at)
    h.delete(:updated_at)
    h
  end

end
