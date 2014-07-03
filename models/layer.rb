# encoding: UTF-8

class CDKLayer < Sequel::Model(:layers)
  many_to_one :owner
  one_to_many :object_data, class: :CDKObjectDatum
  one_to_many :fields
  many_to_one :category

  KEY_LAYER_NAMES = "layer_names"
  KEY_LAYER_DEPENDENCIES = "layer_dependencies"

  def self.execute_write(query)
    data = query[:data]

    written_layer_id = nil

    required_keys = [
      'name',
      'title',
      'description',
      'data_sources',
      'owner',
      'category'
    ]

    optional_keys = [
      'authoritative',
      'subcategory',
      'update_rate',
      'webservice_url',
      '@context',
      'licence',
      'fields',
      'rdf_type'
    ]

    # Make sure POST data contains only valid keys
    unless (data.keys - (required_keys + optional_keys)).empty?
      query[:api].error!("Incorrect keys found in POST data: #{(data.keys - (required_keys + optional_keys)).join(', ')}", 422)
    end

    # Convert array to pg_array
    if data['data_sources']
      data['data_sources'] = Sequel.pg_array(data['data_sources'])
    end

    # Convert context to JSON
    if data['@context']
      query[:api].error!('JSON-LD context for layer should be JSON object', 422) unless data['@context'].class == Hash
      data['@context'] = data['@context'].to_json
    end

    # If owner and category are provided, make sure
    # owner and category exist, and
    # replace named values in data hash
    if data['owner']
      owner_id = CDKOwner.id_from_name(data['owner']) if data['owner']
      query[:api].error!("Owner does not exist: '#{data['owner']}'", 422) unless owner_id
      data.delete('owner')
      data['owner_id'] = owner_id
    end

    if data['category']
      category_id = CDKCategory.id_from_name(data['category']) if data['category']
      query[:api].error!("Category does not exist: '#{data['category']}'", 422) unless category_id
      data.delete('category')
      data['category_id'] = category_id
    end

    case query[:method]
    when :post
      # create
      
      layer_id = id_from_name(data['name'])
      query[:api].error!("Layer already exists: #{data['name']}", 422) if layer_id

      CDKOwner.verifyDomain(query,data['name'].split('.')[0])

      required_keys = required_keys - ['owner', 'category'] + ['owner_id', 'category_id']

      unless (data.keys & required_keys).sort == required_keys.sort
        query[:api].error!("Cannot create layer, keys are missing in POST data: #{(required_keys - data.keys).join(', ')}", 422)
      end

      Sequel::Model.db.transaction do
        fields = nil
        if data['fields']
          fields = data['fields']
          data.delete('fields')
        end
        written_layer_id = insert(data)
        if fields
          CDKField.multi_insert(fields.map {|field| field[:layer_id] = written_layer_id; field })
        end
      end
      update_layer_hash


    when :patch
      # update
      

      query[:api].error!('Layer name cannot be changed', 422) if data['name']

      layer_id = self.id_from_name query[:params][:layer]
      if layer_id
        CDKOwner.verifyOwnerForLayer(query, layer_id)
        Sequel::Model.db.transaction do
          if data['fields']
            CDKField.where(layer_id: layer_id).delete
            CDKField.multi_insert(data['fields'].map {|field| field[:layer_id] = layer_id; field })
            data.delete('fields')
          end
          where(id: layer_id).update(data)
        end
        update_layer_hash
      else
        query[:api].error!("Layer not found: #{query[:params][:layer]}", 404)
      end
      written_layer_id = layer_id
    when :put
      # Only used for:
      # PUT /layers/:layer/@context

      # POST data should only contain one key: '@context
      query[:api].error!('Incorrect keys found in POST data', 422) unless data.keys == ['@context']

      layer_id = self.id_from_name query[:params][:layer]
      if layer_id
        CDKOwner.verifyOwnerForLayer(query, layer_id)
        where(id: layer_id).update(data)
        update_layer_hash
      else
        query[:api].error!("Layer not found: #{query[:params][:layer]}", 404)
      end
      written_layer_id = layer_id
    end

    dataset.where(id: written_layer_id)
  end

  def self.execute_delete(query)
    layer_id = self.id_from_name query[:params][:layer]
    if layer_id == -1
      query[:api].error!("Layer 'none' cannot be deleted", 422)
    elsif layer_id
      CDKOwner.verifyOwnerForLayer(query, layer_id)
      
      # Move objects on layer to be deleted which still have
      # data on other layer to layer = -1
      # Example:
      #  - Object A (on layer 1) has data on both layers 1 and 2.
      #  - Layer 1 is removed
      #  - Object A is moved to layer -1, and has data on layer 2.

      # TODO: create SQL function in 003_functions migration
      move_objects = <<-SQL
        UPDATE objects SET layer_id = -1
        WHERE id IN (
          SELECT id FROM objects AS o2
          WHERE o2.layer_id = ? AND EXISTS (
            SELECT TRUE FROM object_data
            WHERE o2.id = object_id
            AND object_data.layer_id != o2.layer_id
            AND o2.layer_id != -1
          )
        );
      SQL

      Sequel::Model.db.transaction do
        Sequel::Model.db.fetch(move_objects, layer_id).all
        where(id: layer_id).delete
        CDKObject.delete_orphans
        update_layer_hash
      end
    else
      query[:api].error!("Layer not found: #{query[:params][:layer]}", 404)
    end
  end

  def self.memcached_key(id)
    "layer!!#{id}"
  end

  def self.get_layer(id)
    ensure_layer_cache
    key = memcached_key(id)
    CitySDKLD.memcached_get(key)
  end

  def self.get_layer_names
    ensure_layer_cache
    CitySDKLD.memcached_get(KEY_LAYER_NAMES)
  end

  def self.get_layer_dependencies
    ensure_layer_cache
    CitySDKLD.memcached_get(KEY_LAYER_DEPENDENCIES)
  end

  def self.ensure_layer_cache
    unless CitySDKLD.memcached_get(KEY_LAYER_NAMES)
      update_layer_hash
    end
  end

  def self.get_dataset(query)
    dataset.select{id}.order(:id).where('id >= 0')
  end

  def self.make_hash(l)
    l[:@context] = JSON.parse(l[:@context], symbolize_names: true) if l[:@context]

    l[:wkt] = l[:wkt].round_coordinates(CitySDKLD::Serializers::COORDINATE_PRECISION) if l[:wkt]
    l[:geojson] = JSON.parse(l[:geojson].round_coordinates(CitySDKLD::Serializers::COORDINATE_PRECISION), symbolize_names: true) if l[:geojson]

    l
  end

  def self.get_dependent(layer_ids)
    deps = get_layer_dependencies

    # layers included because they are linked to by 'virtual' layers
    source_ll = []

    # the 'virtual' layers
    target_ll = []
    layer_ids.each do |id|
      if deps[id]
        target_ll << id

        # only include if not already present in the requested layers
        source_ll << deps[id] unless layer_ids.include?(deps[id])
      end
    end
    return source_ll.flatten.uniq, target_ll.flatten.uniq, deps
  end

  def self.id_from_name(name)
    ensure_layer_cache
    get_layer_names[name]
  end

  def self.name_from_id(id)
    layer = self.get_layer(id)
    layer[:name]
  end

  ##########################################################################################
  # Real-time/web service layers:
  ##########################################################################################

  def self.is_webservice?(id)
    layer = self.get_layer(id)
    webservice_url = layer[:webservice_url]
    webservice_url and webservice_url.length > 0
  end

  def self.get_webservice_url(id)
    layer = self.get_layer(id)
    layer[:webservice_url]
  end

  def self.get_data_timeout(id)
    layer = self.get_layer(id)
    layer[:update_rate] || 3000
  end

  ##########################################################################################
  # Initialize layers hash:
  ##########################################################################################

  def self.update_layer_hash(layer_id = nil)
    names = {}
    deps = {}

    columns = (CDKLayer.dataset.columns - [:geom])
    dataset = CDKLayer.select{columns}.select_append(
      Sequel.function(:ST_AsGeoJSON, :geom).as(:geojson),
      Sequel.function(:ST_AsText, :geom).as(:wkt)
    )

    categories = CDKCategory.to_hash(:id, :name)

    dataset = dataset.where(id: layer_id) if layer_id

    dataset.all.each do |l|
      values = l.values

      values[:owner] = CDKOwner.make_hash(CDKOwner.where(id: values[:owner_id]).first)
      values[:fields] = CDKField.where(layer_id: values[:id]).all.map { |f| CDKField.make_hash(f.values) }

      values[:category] = categories[values[:category_id]]
      values.delete(:category_id)

      layer = make_hash values
      deps[layer[:id]] = layer[:depends_on_layer_id] if (layer[:depends_on_layer_id] && layer[:depends_on_layer_id] != 0)
      # Save layer data in memcache without expiration
      key = self.memcached_key(layer[:id].to_s)
      CitySDKLD.memcached_set(key, layer, 0)
      names[layer[:name]] = layer[:id]
    end

    # Only if ALL layers were reloaded, update memcached names and deps
    unless layer_id
      CitySDKLD.memcached_set(KEY_LAYER_NAMES, names, 3600)
      CitySDKLD.memcached_set(KEY_LAYER_DEPENDENCIES, deps, 3600)
    end
  end

end

