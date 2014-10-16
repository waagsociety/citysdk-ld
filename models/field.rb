# encoding: UTF-8

class CDKField < Sequel::Model(:fields)
  many_to_one :layer

  def self.get_dataset(query)
    self.dataset
  end

  def self.execute_write(query)
    data = query[:data]

    written_layer_id = nil
    written_field_name = nil

    layer_id = CDKLayer.id_from_name query[:params][:layer]
    unless layer_id
      query[:api].error!("Layer not found: #{query[:params][:layer]}", 404)
    end

    CDKOwner.verify_owner_for_layer(query, layer_id)

    #TODO: type should be a required field
    keys = [
      'name',
      'lang',
      'type',
      'unit',
      'description',
      'equivalentProperty'
    ]

    # Make sure POST data contains only valid keys
    unless (data.keys - keys).empty?
      query[:api].error!("Incorrect keys found in field PUT/POST data: #{(data.keys - keys).join(', ')}", 422)
    end

    case query[:method]
    when :post
      # create

      # 'name' must exist in POST data
      if data['name']
        field = field_from_name_and_layer_id(data['name'], layer_id)
        if field
          query[:api].error!("Field already exists: #{data['name']}", 422)
        end
        CDKField.insert({layer_id: layer_id}.merge(data))
      else
        query[:api].error!('Field must have a name', 422)
      end

      written_layer_id = layer_id
      written_field_name = data['name']

    when :put, :patch
      query[:api].error!('Field name cannot be changed', 422) if data['name']
      field = field_from_name_and_layer_id(query[:params][:field], layer_id)

      query[:api].error!("Field not found: #{query[:params][:field]}", 404) unless field

      written_layer_id = layer_id
      written_field_name = query[:params][:field]
      case query[:method]
      when :put
        # overwrite

        name = field[:name]
        field.delete
        CDKField.insert(data.merge({layer_id: layer_id, name: name}))
      when :patch
        # update

        field.update(data)
      end
    end
    dataset.where(layer_id: written_layer_id, name: written_field_name)
  end

  def self.execute_delete(query)
    layer_id = CDKLayer.id_from_name query[:params][:layer]
    if layer_id
      CDKOwner.verify_owner_for_layer(query, layer_id)
      count = CDKField.where(layer_id: layer_id, name: query[:params][:field]).delete
      if count == 0
        query[:api].error!("Field not found: #{query[:params][:field]}", 404)
      end
    else
      query[:api].error!("Layer not found: #{query[:params][:layer]}", 404)
    end
  end

  def self.field_from_name_and_layer_id(name, layer_id)
    CDKField.where(layer_id: layer_id, name: name).first
  end

  def self.make_hash(l)
    l.delete(:layer_id)
    l.delete_if{ |_, v| v.blank? }
  end

end
