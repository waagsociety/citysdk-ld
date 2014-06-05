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
      'update_rate',
      'webservice_url',
      'context',
      'licence',
      'fields'
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
    if data['context']
      query[:api].error!('JSON-LD context for layer should be JSON object', 422) unless data['context'].class == Hash
      data['context'] = data['context'].to_json
    end

    # If owner and category are provided, make sure
    # owner and category exist
    owner_id = nil
    owner_id = CDKOwner.id_from_name(data['owner']) if data['owner']

    category_id = nil
    category_id = CDKCategory.id_from_name(data['category']) if data['category']

    case query[:method]
    when :post
      # create

      layer_id = id_from_name(data['name'])
      query[:api].error!("Layer already exists: #{data['name']}", 422) if layer_id

      unless (data.keys & required_keys).sort == required_keys.sort
        query[:api].error!("Cannot create layer, keys are missing in POST data: #{(required_keys - data.keys).join(', ')}", 422)
      end

      # owner_id and category_id must be valid;
      # and replace named values in data hash
      if owner_id
        data.delete('owner')
        data['owner_id'] = owner_id
      else
        query[:api].error!("Owner does not exist: #{data['owner']}", 422)
      end

      if category_id
        data.delete('category')
        data['category_id'] = category_id
      else
        query[:api].error!("Category does not exist: #{data['category']}", 422)
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
      update_layer_hashes
    when :patch
      # update

      query[:api].error!('Layer name cannot be changed', 422) if data['name']

      # owner_id and category_id must be valid;
      # and replace named values in data hash
      if owner_id
        data.delete('owner')
        data['owner_id'] = owner_id
      end

      if category_id
        data.delete('category')
        data['category_id'] = category_id
      end

      layer_id = self.id_from_name query[:params][:layer]
      if layer_id
        Sequel::Model.db.transaction do
          if data['fields']
            CDKField.where(layer_id: layer_id).delete
            CDKField.multi_insert(data['fields'].map {|field| field[:layer_id] = layer_id; field })
            data.delete('fields')
          end
          where(id: layer_id).update(data)
        end
        update_layer_hashes
      else
        query[:api].error!("Layer not found: #{query[:params][:layer]}", 404)
      end
      written_layer_id = layer_id
    when :put
      # Only used for:
      # PUT /layers/:layer/context

      # POST data should only contain one key: 'context
      query[:api].error!('Incorrect keys found in POST data', 422) unless data.keys == ['context']

      layer_id = self.id_from_name query[:params][:layer]
      if layer_id
        where(id: layer_id).update(data)
        update_layer_hashes
      else
        query[:api].error!("Layer not found: #{query[:params][:layer]}", 404)
      end
      written_layer_id = layer_id
    end

    dataset.where(id: written_layer_id)
  end

  def self.execute_delete(query)
    # TODO: Doe alle nodes van alle lagen van deze owner die wel data hebben op laag -1!

    layer_id = self.id_from_name query[:params][:layer]
    if layer_id == -1
      query[:api].error!("Layer 'none' cannot be deleted", 422)
    elsif layer_id
      where(id: layer_id).delete
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
      update_layer_hashes
    end
  end

  def self.get_dataset(query)
    dataset.select{id}.order(:id).where('id >= 0')
  end

  def self.make_hash(l)
    l[:context] = JSON.parse(l[:context], {symbolize_names: true}) if l[:context]

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

  # Temporarily disabled this function,
  # only useful when wildcards (and query UNIONs) are again supported
  # # TODO: refactor: rename p, rename layer_names!
  # def self.ids_from_names(p)
  #   # Accepts full layer names and layer names
  #   # with wildcards after dot layer separators:
  #   #    cbs.*
  #   case p
  #   when Array
  #     return p.map { |name|  self.ids_from_names(name) }.flatten.uniq
  #   when String
  #     layer_names = self.get_layer_names
  #     if layer_names
  #       if p.include? "*"
  #         raise "Wildcards in layer filters are not yet supported"
  #
  #         # wildcards can only be used once, on the end of layer specifier after "." separator
  #         if p.length >= 3 and p.scan("*").size == 1 and p.scan(".*").size == 1 and p[-2,2] == ".*"
  #           prefix = p[0..(p.index("*") - 1)]
  #           layer_ids = layer_names.select{|k,v| k.start_with? prefix}.values
  #           if layer_ids.length > 0
  #             return layer_ids
  #           else
  #             raise "No layers found: '#{p}'"
  #           end
  #         else
  #           raise "You can only use wildcards in layer names directly after a name separator (e.g. osm.*)"
  #         end
  #       else
  #         if layer_names[p]
  #           return layer_names[p]
  #         else
  #           raise "Layer not found: '#{p}'"
  #         end
  #       end
  #     else
  #       # No layer names available, something went wrong
  #       raise 'Layer cache unavailable'
  #     end
  #   end
  # end

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

  # TODO: use associations!?
  def self.update_layer_hashes
    names = {}
    deps = {}

    columns = (CDKLayer.dataset.columns - [:geom])
    CDKLayer.select{columns}.select_append(
      Sequel.function(:ST_AsGeoJSON, :geom).as(:geojson),
      Sequel.function(:ST_AsText, :geom).as(:wkt)
    ).all.each do |l|
      l.values[:owner] = CDKOwner.make_hash(CDKOwner.where(:id => l.values[:owner_id]).first)
      l.values[:fields] = CDKField.where(:layer_id => l.values[:id]).all.map { |l| CDKField.make_hash(l.values) }

      layer = make_hash(l.values)
      deps[layer[:id]] = layer[:depends_on_layer_id] if (layer[:depends_on_layer_id] && layer[:depends_on_layer_id] != 0)
      # Save layer data in memcache without expiration
      key = self.memcached_key(layer[:id].to_s)
      CitySDKLD.memcached_set(key, layer, 0)
      names[layer[:name]] = layer[:id]
    end

    CitySDKLD.memcached_set(KEY_LAYER_NAMES, names, 3600)
    CitySDKLD.memcached_set(KEY_LAYER_DEPENDENCIES, deps, 3600)

  end

end

