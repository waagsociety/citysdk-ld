# encoding: UTF-8

module CitySDKLD
  class API < Grape::API

    default_format :json
    format :json
    version 'v1', using: :header, vendor: 'citysdk-ld'

    def initialize
      super

      # TODO: is this the right place to connect do DB?
      # how does this work on server with nginx + spawning?
      @config = JSON.parse(File.read("./config.#{ENV["RACK_ENV"]}.json"), symbolize_names: true)

      @database = Sequel.connect "postgres://#{@config[:db][:user]}:#{@config[:db][:password]}@#{@config[:db][:host]}/#{@config[:db][:database]}"

      #@database.logger = Logger.new(STDOUT)

      Sequel.extension :pg_hstore_ops
      Sequel.extension :pg_array_ops

      @database.extension :pg_array
      @database.extension :pg_range
      @database.extension :pg_hstore

      Sequel::Model.db.extension :pagination

      Dir[File.expand_path('../../models/*.rb', __FILE__)].each { |file| require file }
      Dir[File.expand_path('../../utils/*.rb', __FILE__)].each { |file| require file }

      CDKLayer.update_layer_hashes
    end

    def self.add_serializer(serializer)
      content_type serializer::FORMAT, serializer::CONTENT_TYPE
      formatter serializer::FORMAT, lambda { |object, env|
        set_link_header env["api.endpoint"], object
        s = serializer.new
        s.serialize object, env
      }
    end

    def self.set_link_header(api, object)
      # Use GitHub style pagination headers
      # https://developer.github.com/v3/#pagination
      pagination = object[:query][:internal][:pagination] rescue nil
      if pagination
        links = {}

        links[:first] = 1 if pagination[:current_page] > 1
        links[:prev] = pagination[:current_page] - 1 if pagination[:current_page] > 1

        count = pagination[:pagination_record_count]

        if object[:data].length < pagination[:page_size]
          # Less objects are returned than were asked for,
          # this must be the last page!
          links[:last] = pagination[:current_page]
          count = object[:data].length + (pagination[:current_page] - 1) * pagination[:page_size]
        else
          links[:last] = pagination[:page_count] if pagination[:page_count]
          links[:next] = pagination[:current_page] + 1 unless pagination.key? :page_count && pagination[:current_page] == pagination[:page_count]
        end
        path = 'http://' + object[:query][:host] + '/' + object[:query][:path].join('/')
        params = object[:query][:params]
            .reject { |param,_| [:page, :per_page].include? param }
            .map { |param, value| param.to_s + (value ? "=#{value}" : '') }
            .join('&')
        params += '&' if params.length > 0

        # Set link header
        api.header 'Link', links.map { |link, page| "<#{path}?#{params}page=#{page}&per_page=#{pagination[:page_size]}>; rel=\"#{link}\"" }.join(', ')
        # Set count header if count is available
        api.header 'X-Result-Count', count.to_s if count
      end
    end

    add_serializer ::CitySDKLD::Serializers::GeoJSONSerializer
    add_serializer ::CitySDKLD::Serializers::TurtleSerializer
    add_serializer ::CitySDKLD::Serializers::JSONLDSerializer

    # URI structure uses HTTP verbs for resources:
    # https://developer.github.com/v3/#http-verbs
    mount ::CitySDKLD::Layers
    mount ::CitySDKLD::Objects
    mount ::CitySDKLD::Owners
    mount ::CitySDKLD::Endpoints

    # TODO: swagger should specify possible output formats!
    add_swagger_documentation api_version: 'v1'

  end
end
