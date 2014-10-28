# encoding: UTF-8

require_relative 'object.rb'

class CDKObjectDatum < Sequel::Model(:object_data)
  many_to_one :object
  many_to_one :layer

  def self.layer_on_object(nd)
    {
      created_at: nd[:created_at],
      updated_at: nd[:updated_at]
    }
  end

  def self.get_dataset(query)
    dataset = self.dataset
  end

  def self.data_valid?(data)
    # Object data can never be empty

    # We are still using postgres's hstore to store data,
    # data should be unnested.
    # The following classes are allowed for value.class:
    # [String, NilClass, Fixnum, Float, Numeric, TrueClass, FalseClass]
    nested = false
    data.values.each do |value|
      nested |= ![String, Fixnum, NilClass, Float, Numeric, TrueClass, FalseClass].include?(value.class)
    end
    # data is valid when not nested
    not nested
  end

  def self.execute_write(query)

    # POST data should be present
    unless query[:data] and query[:data].keys.length > 0
      query[:api].error!('No POST data present', 422)
    end

    data = query[:data]
    return self.where(true) if data.keys.count == 0
    if ! data_valid?(data)
      query[:api].error!("'data' object in POST data cannot contain arrays or objects", 422)
    end

    layer_id = CDKLayer.id_from_name(query[:params][:layer])
    query[:api].error!("Layer not found: '#{query[:params][:layer]}'", 404) unless layer_id

    CDKOwner.verify_owner_for_layer(query, layer_id)

    object_datum = CDKObjectDatum.get_from_object_and_layer(query[:params][:cdk_id], layer_id)
    query[:api].error!("Object not found: '#{query[:params][:cdk_id]}'", 404) unless object_datum

    case query[:method]
    when :post
      # create
      if object_datum[:id]
        # Data already exists for :cdk_id on :layer, abort!
        query[:api].error!("Data already exists on layer for: '#{query[:params][:cdk_id]}'", 409)
      else
        self.insert(object_id: object_datum[:object_id], data: Sequel.hstore(data), layer_id: layer_id)
      end
      ds = self.where({ object_id: object_datum[:object_id], layer_id: layer_id})
    when :put
      # overwrite
      if object_datum[:id]
        self.where(id: object_datum[:id]).update(data: Sequel.hstore(data))
      else
        # No data exists for :cdk_id on :layer, abort!
        query[:api].error!("No data exists on layer for: '#{query[:params][:cdk_id]}'", 404)
      end
      ds = self.where(id: object_datum[:id])
    when :patch
      # update

      if object_datum[:id]
        data = object_datum[:data].merge(data)
        self.where(id: object_datum[:id]).update(data: Sequel.hstore(data))
      else
        # No data exists for :cdk_id on :layer, abort!
        query[:api].error!("No data exists on layer for: '#{query[:params][:cdk_id]}'", 404)
      end
      ds = self.where(id: object_datum[:id])
    end
    ds
  end

  def self.execute_delete(query)
    layer_id = CDKLayer.id_from_name query[:params][:layer]
    CDKOwner.verify_owner_for_layer(query, layer_id)
    object_datum = CDKObjectDatum.get_from_object_and_layer(query[:params][:cdk_id], layer_id)

    query[:api].error!("Layer not found: #{query[:params][:layer]}", 404) unless layer_id
    query[:api].error!("Object not found: '#{query[:params][:cdk_id]}'", 404) unless object_datum
    query[:api].error!("No data found on layer '#{query[:params][:layer]}' for object: '#{query[:params][:cdk_id]}'", 404) unless object_datum[:id]

    object_id = object_datum[:object_id]

    Sequel::Model.db.transaction do
      CDKObjectDatum.where(id: object_datum[:id]).delete
      CDKObject.delete_orphans
    end
  end

  def self.get_from_object_and_layer(cdk_id, layer_id)
    CDKObject.left_outer_join(:object_data, object_id: :id, object_data__layer_id: layer_id)
        .where(cdk_id: cdk_id)
        .select(Sequel.lit('objects.id AS object_id'), :object_data__id, :data)
        .first
  end

  def self.db_hash_from_geojson(query, cdk_id, layer_id, feature)
    data = {}
    if feature['properties'] and feature['properties']['data']
      data = feature['properties']['data']
    else
      if layer_id
        layer = CDKLayer.name_from_id(layer_id)
        if feature['properties'] and feature['properties']['layers'] and feature['properties']['layers'][layer]
          data = feature['properties']['layers'][layer]
        else
          query[:api].error!("No object data found for object", 422)
        end
      else
        query[:api].error!("No object data found for object", 422)
      end
    end
    query[:api].error!("Object data cannot contain arrays or objects", 422) unless data_valid? data
    {
      object_id: Sequel.function(:cdk_id_to_internal, cdk_id),
      layer_id: layer_id ? layer_id : Sequel.function(:object_layer_id_from_cdk_id, cdk_id),
      data: Sequel.hstore(data)
    }
  end

  def self.make_hash(nd, object, query)
    layer_id = nd[:layer_id]

    nd.delete(:id)
    nd.delete(:object_id)
    nd.delete(:layer_id)
    nd.delete(:created_at)
    nd.delete(:updated_at)

    if CDKLayer.is_webservice? layer_id
      nd[:data] = WebService.load(layer_id, object, nd[:data], query)
    end

    nd
  end

end
