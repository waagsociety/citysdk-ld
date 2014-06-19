# encoding: UTF-8

module CitySDKLD

  module Filters
    # url_params can be array of symbols or single regex.
    # regex capture groups are converted to filter
    # parameters
    #
    # {write: true} means the filter is also used for
    # POST, PUT, PATCH and DELETE requests
    @@filters = {

      # Read/write filters:
      cdk_id: {
        url_params: [:cdk_id],
        resources: [:objects, :layers, :data, :layer_on_object],
        write: true
      },
      layer: {
        url_params: [:layer],
        resources: [:objects, :layers, :data, :fields, :layer_on_object, :owners],
        write: true
      },
      owner: {
        url_params: [:owner],
        resources: [:owners, :layers],
        write: true
      },
      field: {
        url_params: [:field],
        resources: [:fields],
        write: true
      },

      # Read-only filters:
      in: {
        url_params: [:in],
        resources: [:objects]
      },
      contains: {
        url_params: [:contains],
        resources: [:objects, :layers]
      },
      bbox: {
        url_params: [:bbox],
        resources: [:objects, :layers]
      },
      nearby: {
        url_params: [:lat, :lon],
        resources: [:objects, :layers]
      },
      title: {
        url_params: [:title],
        resources: [:objects, :layers]
      },
      data: {
        url_params: /(?<layer>[\w_\.]+)::(?<field>.+)/,
        resources: [:objects]
      },
      admin: {
        url_params: [:admin],
        resources: [:owners]
      },
      authoritative: {
        url_params: [:authoritative],
        resources: [:layers]
      },
      category: {
        url_params: [:category],
        resources: [:layers]
      }

    }

    ###########################################################################
    # Utility functions
    ###########################################################################

    def self.filters
      @@filters
    end

    def self.create_filter(filter, params)
      {
        filter: filter,
        params: params
      }
    end

    def self.object_data_joins(dataset, query, layer_id)

      # Keep internal list of joined tables
      unless query[:internal].key? :joins
        query[:internal][:joins] = []
      end

      # Only join dataset with layer needed for data filter if not already joined
      unless query[:internal][:joins].include? layer_id
        dataset = dataset.join_table(:inner, :object_data, {layer_id: layer_id, object_id: :objects__id}, {table_alias: "od#{layer_id}"})
      end

      # Add layer_id to joined table array
      query[:internal][:joins] << layer_id
      query[:internal][:joins].uniq!

      dataset
    end

    ###########################################################################
    # Filters:
    #   all filters should check their input variable 'params',
    #   and support, if applicable, multiple input types - string, array, hash
    ###########################################################################

    def self.cdk_id(dataset, params, query)
      # The cdk_id filter works differently for objects and layers
      case query[:resource]
      when :objects
        # Return single objects
        dataset.where(cdk_id: params[:cdk_id])
      when :data, :layer_on_object
        # Returns data on single layer of single object
        dataset.where(object_id: Sequel.function(:cdk_id_to_internal, params[:cdk_id]))
      when :layers
        # Return all layers with data about single objects
        subselect = CDKObjectDatum
            .select(:layer_id)
            .where(object_id: Sequel.function(:cdk_id_to_internal, params[:cdk_id]))
        dataset.where(id: subselect)
      end
    end

    PAGINATE_DEFAULT_PAGE = 1
    PAGINATE_DEFAULT_PER_PAGE = 10
    PAGINATE_MAX_PAGE = 100
    PAGINATE_MAX_PER_PAGE = 1000
    PAGINATE_INFINITY = 1_000_000_000
    def self.paginate(dataset, params, query)
      page = PAGINATE_DEFAULT_PAGE
      per_page = PAGINATE_DEFAULT_PER_PAGE

      if params.key? :page
        page = [PAGINATE_DEFAULT_PAGE, query[:params][:page].to_i].max
        page = [page, PAGINATE_MAX_PAGE].min
      end
      if params.key? :per_page
        per_page = [params[:per_page].to_i, PAGINATE_MAX_PER_PAGE].min
        per_page = PAGINATE_DEFAULT_PER_PAGE if per_page <= 0
      end

      if params.key? :count
        dataset = dataset.paginate(page, per_page)
        query[:internal][:pagination] = {
          current_page: dataset.current_page,
          page_size: dataset.page_size,
          page_count: dataset.page_count,
          pagination_record_count: dataset.pagination_record_count
        }
      else
        dataset = dataset.paginate(page, per_page, PAGINATE_INFINITY)
        query[:internal][:pagination] = {
          current_page: dataset.current_page,
          page_size: dataset.page_size
        }
      end
      dataset
    end

    def self.layer(dataset, params, query)
      layer_ids = []
      unless params[:layer] == '*' and query[:resource] == :objects
        params[:layer].split(',').each do |layer_name|
          layer_id = CDKLayer.id_from_name(layer_name)
          if layer_id
            layer_ids << layer_id
          else
            query[:api].error!("Layer not found: '#{layer_name}'", 404)
          end
        end
      end

      # Get layers dependent on current layers, and get dependency hash
      source_layer_ids, target_layer_ids, deps_hash = CDKLayer.get_dependent(layer_ids)

      # The layer filter works differently for objects and layers
      case query[:resource]
      when :objects
        if params[:layer] == '*'
          # Set query internal parameter
          query[:internal][:layer_ids] = :*
        else
          # Set query internal parameter
          query[:internal][:layer_ids] = layer_ids
          query[:internal][:source_layer_ids] = source_layer_ids
          query[:internal][:target_layer_ids] = target_layer_ids

          # join all layers that others depend on
          source_layer_ids.each do |layer_id|
            dataset = object_data_joins(dataset, query, layer_id)
          end

          layer_ids.each do |layer_id|
            # Only join when not layer is not virtual
            unless deps_hash[layer_id]
              dataset = object_data_joins(dataset, query, layer_id)
            end
          end

        end
      when :layers
        dataset = dataset.where(id: layer_ids)
      when :data, :layer_on_object, :fields
        dataset = dataset.where(layer_id: layer_ids)
      when :owners
        dataset = dataset.where(id: CDKLayer.select(:owner_id).where(id: layer_ids))
      end

      dataset
    end

    def self.bbox(dataset, params, query)
      coordinates = params[:bbox].split(',')
      unless coordinates.length == 4 and coordinates.map {|c| c.is_number? }.inject(:&)
        query[:api].error!("bbox parameter needs to be of form: 'lat1,lon1,lat2,lon2'", 422)
      end
      contains = 'ST_Contains(ST_SetSRID(ST_MakeBox2D(ST_Point(?,?), ST_Point(?, ?)), 4326), geom)'
      dataset.where(contains, coordinates[1], coordinates[0], coordinates[3], coordinates[2])
    end

    def self.nearby(dataset, params, query)
      unless params[:lon].is_number? and params[:lat].is_number?
        query[:api].error!('Both lat and lon parameters need to be valid numbers.', 422)
      end
      lon = params[:lon].to_f
      lat = params[:lat].to_f

      # If radius parameter is included, search for objects inside circle from lat,lon with radius
      # Otherwise (without radius parameter), search for closest items (limited by per_page)
      if query[:params].key? :radius
        unless query[:params][:radius].is_number?
          query[:api].error!('Both radius parameter needs to be valid numbers.', 422)
        end
        radius = query[:params][:radius].to_f

        # Create point on lat, lon, convert to Geography, use ST_Buffer to create circle around
        # point with radius in meters and convert back to 4326.
        # Add ST_Intersects to see if object is within circle.
        intersects = 'ST_Intersects(ST_Transform(Geometry(ST_Buffer(Geography(ST_Transform(ST_SetSRID(ST_Point(?, ?), 4326), 4326)), ?)), 4326), geom)'
        dataset = dataset.where(intersects, lon, lat, radius)
      end

      order = 'geom <-> ST_SetSRID(ST_MakePoint(?, ?), 4326)'
      dataset.order(Sequel.lit(order, lon, lat))
    end

    def self.contains(dataset, params, query)
      object = CDKObject.where(cdk_id: params[:contains]).first
      if object
        intersects = Sequel.function(:ST_Intersects, object.geom, :geom)
        dataset.where(intersects).where(Sequel.~(cdk_id: params[:contains]))
      else
        query[:api].error!("Object not found: '#{params[:contains]}'", 404)
      end
    end

    def self.in(dataset, params, query)
      object = CDKObject.where(cdk_id: params[:in]).first
      if object
        contains = Sequel.function(:ST_Contains, object.geom, :geom)
        dataset.where(contains)
      else
        query[:api].error!("Object not found: '#{params[:in]}'", 404)
      end
    end

    def self.title(dataset, params, query)
      title = params[:title]
      # dataset.where('title % ?'.lit(Sequel.expr(params[:title])))
      dataset.where(Sequel.expr(:title).ilike("%#{title}%"))
        .order(Sequel.desc(Sequel.function(:similarity, :title, title)))
    end

    def self.field(dataset, params, query)
      dataset.where(name: params[:field])
    end

    def self.owner(dataset, params, query)
      case query[:resource]
      when :owners
        dataset.where(name: params[:owner])
      when :layers
        dataset.where(owner_id: CDKOwner.select(:id).where(name: params[:owner]))
      end
    end

    def self.data(dataset, params, query)
      layer_id = CDKLayer.id_from_name(params[:layer])
      unless layer_id
        query[:api].error!("Layer not found: '#{params[:layer]}'", 404)
      end

      dataset = object_data_joins(dataset, query, layer_id)

      # Always add layers queried by data filters to final output,
      # keep list of layers, serializer uses this list and adds layers
      unless query[:internal].key? :data_layer_ids
        query[:internal][:data_layer_ids] = []
      end
      query[:internal][:data_layer_ids] << layer_id

      expr = Sequel.expr(:data).qualify("od#{layer_id}").hstore
      if params[:value]
        expr = expr.contains(Sequel.hstore({params[:field] => params[:value]}))
      else
        expr = expr.key? params[:field]
      end
      dataset.where(expr)
    end

    def self.admin(dataset, params, query)
      a = params[:admin].to_bool
      if a == nil
        dataset
      else
        dataset.where(admin: a)
      end
    end

    def self.authoritative(dataset, params, query)
      a = params[:authoritative].to_bool
      if a == nil
        dataset
      else
        dataset.where(authoritative: a)
      end
    end

    def self.category(dataset, params, query)
      dataset.where(category_id: CDKCategory.select(:id).where(name: params[:category]))
    end

    # def self.in_set
    #   .where(:objects__id => Sequel.function(:ANY, Sequel.function(:get_members, cdk_id)))
    #   .order(Sequel.function(:idx, Sequel.function(:get_members, cdk_id), :objects__id))
    # end

    # def route_members(params)
    #   # The starts_in, ends_in and contains parameters are used to
    #   # filter on routes starting, ending and containing certain
    #   # cdk_ids as members. The order of the cdk_ids in the contains
    #   # parameter are always respected.
    #   # The contains parameter is of form:
    #   # <cdk_id>[,<cdk_id>]
    #
    #   dataset = self
    #
    #   if params.key? "starts_in"
    #     starts_in = params["starts_in"]
    #     dataset = dataset.where(Sequel.function(:cdk_id_to_internal, starts_in) => Sequel.pg_array(:members)[Sequel.function(:array_lower, :members, 1)])
    #   end
    #
    #   if params.key? "ends_in"
    #     ends_in = params["ends_in"]
    #     dataset = dataset.where(Sequel.function(:cdk_id_to_internal, ends_in) => Sequel.pg_array(:members)[Sequel.function(:array_upper, :members, 1)])
    #   end
    #
    #   if params.key? "contains"
    #     cdk_ids = params["contains"].split(",")
    #     if cdk_ids.length > 0
    #       # members @> ARRAY[cdk_id_to_internal('n712651044'), cdk_id_to_internal('w6637691')]
    #       ids = cdk_ids.map { |cdk_id|
    #         Sequel.function(:cdk_id_to_internal, cdk_id)
    #       }
    #       dataset = dataset.where(Sequel.pg_array(:members).contains(ids))
    #
    #       if cdk_ids.length > 1
    #         # Just check if route contains cdk_ids is not enough:
    #         # order should be checked as well.
    #         # TODO: this approach is not the most efficient,
    #         # cdk_id_to_internal and idx are called twice for each cdk_id...
    #
    #         for i in 0..(cdk_ids.length - 2)
    #           cdk_id1 = cdk_ids[i]
    #           cdk_id2 = cdk_ids[i + 1]
    #
    #           idx1 = Sequel.function(:idx, :members, Sequel.function(:cdk_id_to_internal, cdk_id1))
    #           idx2 = Sequel.function(:idx, :members, Sequel.function(:cdk_id_to_internal, cdk_id2))
    #
    #           dataset = dataset.where(idx1 < idx2)
    #         end
    #       end
    #     end
    #   end
    #
    #   return dataset
    # end

  end

end
