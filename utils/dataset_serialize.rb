# encoding: UTF-8

module Sequel
  class Dataset

    # TODO: move to model classes - execute_write
    def serialize(query)
      params = query[:params]

      data = nil
      layers = {}

      case query[:resource]
      when :objects
        objects = self.to_hash

        if params[:cdk_id] and objects.keys.length == 0
          query[:api].error!("Object not found: '#{params[:cdk_id]}'", 404)
        end

        layer_ids = []
        object_data = []
        layer_sources = query[:internal][:source_layer_ids] || []

        if (query[:internal].key? :layer_ids or query[:internal].key? :data_layer_ids) and objects.keys.length > 0
          dataset = CDKObjectDatum.dataset.where(object_id: objects.values.map { |object| object[:id] } )
          if query[:internal][:layer_ids] != :*
            layer_ids += query[:internal][:layer_ids] if query[:internal].key? :layer_ids
            layer_ids += query[:internal][:data_layer_ids] if query[:internal][:data_layer_ids]

            layer_ids.uniq!
            dataset = dataset.where(layer_id: layer_ids + layer_sources)
          end
          object_data = dataset.all.map { |d| d.values }
        end

        if object_data.length > 0
          data = {}
          object_data.each do |d|
            layer_name = CDKLayer.name_from_id(d[:layer_id])
            layer_ids << d[:layer_id]
            object_id = d[:object_id]
            unless data[object_id]
              data[object_id] = CDKObject.make_hash(objects[object_id].values)
              data[object_id][:layers] = {}
            end
            data[object_id][:layers][layer_name] = CDKObjectDatum.make_hash(d, data[object_id], query)
          end

          # add the 'virtual, target layers'
          if query[:internal][:target_layer_ids] and query[:internal][:source_layer_ids]
            query[:internal][:target_layer_ids].each do |layer_id|
              layer_name = CDKLayer.name_from_id(layer_id)
              data.each_key do |object_id|
                data[object_id][:layers][layer_name] = CDKObjectDatum.make_hash({layer_id: layer_id, data: {}}, data[object_id], query)
              end
            end

            # and remove the layers no longer requested
            query[:internal][:source_layer_ids].each do |layer_id|
              layer_name = CDKLayer.name_from_id(layer_id)
              data.each_key do |object_id|
                data[object_id][:layers].delete(layer_name)
              end
            end
          end

          # data is hash mapping object_ids to objects
          # resulting data should just be list of objects
          data = data.values
        else
          data = objects.values.map do |o|
            CDKObject.make_hash(o.values)
          end
        end

        layer_ids.uniq.each do |layer_id|
          layer = CDKLayer.get_layer layer_id
          layers[layer[:name]] = layer
        end

      when :layers

        # Postgres result in self.all only contains layer_ids
        # Get layers data from internal layers hash
        layer_ids = self.all.map { |a| a.values[:id] }

        if params[:layer] and layer_ids.length == 0 and query[:single]
          query[:api].error!("Layer not found: '#{params[:layer]}'", 404)
        end

        data = layer_ids.map { |layer_id| CDKLayer.get_layer(layer_id) }
      when :data
        #TODO take care of virtual layers
        data = self.all.map { |d| CDKObjectDatum.make_hash(d.values, {cdk_id: params[:cdk_id]}, query)[:data] }
      when :layer_on_object
        data = self.all.map { |d| CDKObjectDatum.layer_on_object(d.values) }
      when :fields
        data = self.all.map { |f| CDKField.make_hash(f.values) }
      when :owners
        data = self.all.map { |o| CDKOwner.make_hash(o.values, query) }
        query[:api].error!("Owner not found: '#{params[:owner]}'", 404) if data.length == 0 and query[:single]
      end

      {
        resource: query[:resource],
        query: query,
        layers: layers,
        data: data
      }
    end

  end
end