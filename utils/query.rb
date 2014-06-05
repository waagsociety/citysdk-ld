# encoding: UTF-8

module CitySDKLD

  class Query

    def initialize(resource, single, env)
      api = env["api.endpoint"]

      # Build params hash from routing arguments and query parameters
      params = env["rack.routing_args"].delete_if {|k, _| [:route_info, 'method', 'path'].include? k }.merge (
        Hash[env["rack.request.query_hash"].map {|k, v| [k.to_sym, v] }]
      )

      # Grape accepts requests with more than one consecutive slash, e.g.:
      #   http://hostname/layers///:layer///objects
      # We don't want this! Check env["REQUEST_PATH"]!
      if /\/{2,}/.match(env["REQUEST_PATH"])
        api.error!('Not found', 404)
      end

      # Also, it seems that Grape allows arbitrary file name extensions by default:
      #   /layers/:layer/objects.some_weird_extension
      # Check if params[:format] is correct, throw error otherwise.
      if params[:format]
        unless api.settings[:content_types].keys.include? params[:format].to_sym
          api.error!("The requested format '#{params[:format]}' is not supported.", 406)
        end
      end

      # Set HTTP request method - GET, POST, PUT, PATCH, DELETE
      method = env['REQUEST_METHOD'].downcase.to_sym

      if method == :post
        # POST request always create new resources
        # Set API status code to 201 - Created
        # If API fails before resource is actually
        # created in DB, status code will be overwritten.
        api.status 201
      end

      # The new query's filters are composed from four sources,
      # in the following order:
      #   1. filters from function call (filters parameter) -
      #      these are also in params, so no need to add separately
      #   2. filters from URL shortcuts - url_parameters in Filter module
      #   3. filters from query parameter - ?query={}
      #   4. filters from POST JSON

      # 2.
      filters = filters_from_params resource, method, params

      # 3.
      if params[:query]
        begin
          query = JSON.parse(params[:query], {symbolize_names: true})
          if query.kind_of? Array
            filters += query
          else
            # TODO: error!
          end
        rescue JSON::ParserError
          api.error!("Error parsing JSON in query parameter", 422)
        end
      end

      # 4.
      post = {}
      if env["rack.request.form_vars"] and env["rack.request.form_vars"].strip.length > 0
        begin
          post = JSON.parse(env["rack.request.form_vars"])
        rescue
          api.error!("Error parsing JSON in POST data", 422)
        end
      end
      # TODO: see if method is GET, and if so, if post contains :query
      # Use filters from post query as well.

      path = env['PATH_INFO']
          .split('/')
          .delete_if { |part| part == '' or not part }
          .map { |part| part.to_sym }

      @q = {
        method: method,
        host: env['HTTP_HOST'],
        format: env['api.format'].to_sym,
        data: post,
        resource: resource,
        single: single,
        path: path,
        filters: filters,
        params: params,
        internal: {},
        api: api
      }
    end

    def filters_from_params(resource, method, params)
      filters = Filters.filters.map do |name, filter|

        # Only use filters that apply to current resource and method
        if filter[:resources].include?(resource) and not (method != :get and not filter[:write])

          # See if all filter's url_params are in params
          all_url_params = true
          filter_params = {}
          filter[:url_params].map do |url_param|
            case url_param
            when Symbol
              if params.keys.include? url_param
                filter_params[url_param] = params[url_param]
              else
                all_url_params = false
              end
            when Regexp
              matched = false
              params.each do |param, value|
                match = url_param.match(param)
                if match
                  filter_params.merge!({
                    layer: match[:layer],
                    field: match[:field],
                    value: value
                  })
                  matched = true
                  break
                end
              end
              all_url_params = false unless matched
            end
          end
          CitySDKLD::Filters.create_filter name, filter_params if all_url_params
        end
      end
      filters.delete_if { |filter| not filter }
    end

    # TODO: move to separate module/class?
    def execute
      begin
        case @q[:method]
        when :get
          read
        when :post, :put, :patch
          write
        when :delete
          delete
        end
      rescue Sequel::Error => e
        CitySDKLD.format_sequel_error(e, @q)
      end
    end

    def write
      dataset = nil
      data = nil
      case @q[:resource]
      when :objects
        data = CDKObject.execute_write @q
        data = {
          resource: :object_write_result,
          data: data,
          query: @q
        }
      when :layers
        dataset = CDKLayer.execute_write @q
      when :context
        # CDKLayer expects string keys in POST data - not symbols
        # TODO: convert ALL input data from request and filters with symbolize_names?
        @q[:data] = {"context" => @q[:data]}
        CDKLayer.execute_write @q

        # TODO: move to Layer model!
        layer_id = CDKLayer.id_from_name(@q[:params][:layer])
        context = CDKLayer.get_layer(layer_id)[:context] rescue {}
        data = {
          resource: @q[:resource],
          data: context ? context : {},
          query: @q
        }
      when :owners
        dataset = CDKOwner.execute_write @q
      when :data
        data = CDKObjectDatum.execute_write @q
      when :fields
        dataset = CDKField.execute_write @q
      end
      data = dataset.serialize(@q) if dataset
      data
    end

    def delete
      case @q[:resource]
      when :objects
        CDKObject.execute_delete @q
      when :layers
        CDKLayer.execute_delete @q
      when :owners
         CDKOwner.execute_delete @q
      when :data
         CDKObjectDatum.execute_delete @q
      when :fields
        CDKField.execute_delete @q
      end

      # If execute_delete function did not result in error, resource is deleted
      # return 204 No Content with empty body
      @q[:api].error!(nil, 204)
    end

    def read
      dataset = nil
      data = nil
      case @q[:resource]
      when :objects
        dataset = CDKObject.get_dataset @q
      when :layers
        dataset = CDKLayer.get_dataset @q
      when :owners
        dataset = CDKOwner.get_dataset @q
      when :data, :layer_on_object
        dataset = CDKObjectDatum.get_dataset @q
      when :fields
        dataset = CDKField.get_dataset @q
      when :endpoints
        # TODO: move to endpoint model
        data = {
          resource: @q[:resource],
          data: {TODO: 'hier alles over endpoint!'},
          query: @q
        }
      when :context
        # TODO: move to Layer model!
        layer_id = CDKLayer.id_from_name(@q[:params][:layer])
        unless layer_id
          @q[:api].error!("Layer not found: #{@q[:params][:layer]}", 404)
        end
        context = CDKLayer.get_layer(layer_id)[:context] rescue {}
        data = {
          resource: @q[:resource],
          data: context ? context : {},
          query: @q
        }
      end

      data = dataset.execute_query(@q).serialize(@q) if dataset
      data
    end

  end

end
