# encoding: UTF-8

require_relative 'serializer.rb'

module CitySDKLD

  module Serializers

    class JSONSerializer < Serializer

      FORMAT = :json
      CONTENT_TYPE = 'application/json'

      def start
        @result = {}
      end

      def finish
        @result.to_json
      end

      def objects
        @result[:results] =  []
        @data.each do |object|
          result = {
            cdk_id: object[:cdk_id],
            title: object[:title]
          }
          result[:geom] = JSON.parse(object[:geom].round_coordinates(Serializers::COORDINATE_PRECISION)) if object[:geom]
          result[:layers] = object[:layers] if object.key? :layers and object[:layers]
          result[:layer] = object[:layer]
          @result[:results] << result
        end
      end

      def layers
        @result[:results] =  []
        @data.each do |layer|
          result = {
            name: layer[:name],
            title: layer[:title],
            description: layer[:description],
            category: layer[:category],
            organization: layer[:organization],
            dataSources: layer[:data_sources],
            update_rate: layer[:update_rate],
            webservice_url: layer[:webservice_url],
            imported_at: layer[:imported_at],
            :@context => layer[:@context],
            geom: layer[:geojson] ? layer[:geojson] : nil
          }
          result.delete_if { |k, v| v.nil? }
          @result[:results] << result
        end
      end

      # def status
      #   @result.merge @data
      # end

    end
  end
end
