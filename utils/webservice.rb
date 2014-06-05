# encoding: UTF-8

class CDKObjectDatum
  module WebService
    require 'faraday'
    require 'net/http'
    require 'uri'

    def self.memcached_key(layer_id, cdk_id)
      l = CDKLayer.name_from_id(layer_id)
      "#{l}!!#{cdk_id}"
    end

    def self.load_from_ws(url, data, object, query, layer_id)
      params = query[:params]
      if url =~ /CDK\:\/\/(.+)/
        return CDKCommands.process_command($1, data, object, params)
      end

      response = nil
      begin
        connection = Faraday.new(url: url)
        response = connection.post do |req|
          req.url ''
          req.body = data.to_json

          # open/read timeout in seconds
          req.options[:timeout] = 5

          # connection open timeout in seconds
          req.options[:open_timeout] = 2
        end
      rescue Exception => e
        # when error, hold back for 5 minutes..
        CitySDKLD.memcached_set("hold_back_#{layer_id}", true, 300)
        puts "Load from WebService Exception: #{e.message}"
      end

      if response && response.status == 200
        begin
          r = JSON.parse(response.body)
          return r['data']
        rescue JSON::ParserError
          # TODO: return original data + error message!
          return data
        end
      end
      nil
    end

    def self.load(layer_id, object, hstore, params)
      key = memcached_key(layer_id, object[:cdk_id])
      data = CitySDKLD.memcached_get key
      if data
        return data
      else
        url = CDKLayer.get_webservice_url layer_id
        holdback = CitySDKLD.memcached_get("hold_back_#{layer_id}")
        unless holdback
          data = load_from_ws(url, hstore, object, params, layer_id)
          if data
            CitySDKLD.memcached_set(key, data, CDKLayer.get_data_timeout(layer_id))
            return data
          end
        end
      end
      hstore
    end
  end
end
