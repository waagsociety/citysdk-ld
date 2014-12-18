# encoding: UTF-8

require_relative 'serializer.rb'

module CitySDKLD

  module Serializers

    class GeoJSONSerializer < Serializer

      FORMAT = :json
      CONTENT_TYPE = 'application/json'

      def start
        @env["api.format"] = "json"

        if [:objects, :layers, :endpoints].include? @resource
          @result = {
            type: "FeatureCollection",
            features: []
          }
        end
      end

      def finish
        @result.to_json
      end

      def objects
        @data.each do |object|
          feature = {
            type: "Feature",
            properties: {
              cdk_id: object[:cdk_id],
              title: object[:title],
              layer: object[:layer]
            },
            geometry: object[:geom] ? JSON.parse(object[:geom].round_coordinates(Serializers::COORDINATE_PRECISION)) : {}
          }
          feature[:properties][:layers] = object[:layers] if object.key? :layers and object[:layers]
          @result[:features] << feature
        end
      end

      def layers
        @data.each do |layer|
          feature = {
            type: "Feature",
            properties: {
              name: layer[:name],
              title: layer[:title],
              description: layer[:description],
              category: layer[:category],
              subcategory: layer[:subcategory],
              rdf_type: layer[:rdf_type],
              rdf_prefixes: layer[:rdf_prefixes],
              licence: layer[:licence],
              organization: layer[:organization],
              data_sources: layer[:data_sources],
              update_rate: layer[:update_rate],
              webservice_url: layer[:webservice_url],
              imported_at: layer[:imported_at],
              owner: layer[:owner][:name],
              fields: layer[:fields].map { |field| field[:name] } ,
              context: layer[:context]
            },
            geometry: layer[:geojson] ? layer[:geojson] : {}
          }
          feature.delete_if { |k, v| v.nil? }
          feature[:properties].delete_if { |k, v| v.nil? }
          feature[:properties][:dependsOn] = CDKLayer::name_from_id(layer[:depends_on_layer_id]) if (layer[:depends_on_layer_id] and layer[:depends_on_layer_id] != 0)
          @result[:features] << feature
        end
      end

      def context
        @result = @data
      end

      def object_write_result
        @result = @data
      end

      def owners
       singular_plural
      end

      def fields
        singular_plural
      end

      def layer_on_object
        singular_plural
      end

      def data
        singular_plural
      end

      def endpoints
        @result[:features] << {
          type: "Feature",
          properties: @data.select {|k,_| k != :geometry },
          geometry: @data[:geometry]
        }
      end

      def sessions
        @result = @data
      end

    end
  end

end