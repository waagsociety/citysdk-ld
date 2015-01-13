# encoding: UTF-8

module CitySDKLD

  module Serializers

    # There's no need to output coordinates with
    # infinite decimal places. We will round all
    # coordinates to COORDINATE_PRECISION
    # places with the round_coordinates function.
    #
    # From: http://stackoverflow.com/questions/7167604/how-accurately-should-i-store-latitude-and-longitude
    #
    # decimal  degrees    distance
    # places
    # -------------------------------
    # 3        0.001      111 m
    # 4        0.0001     11.1 m
    # 5        0.00001    1.11 m
    # 6        0.000001   0.111 m
    # 7        0.0000001  1.11 cm
    # 8        0.00000001 1.11 mm
    COORDINATE_PRECISION = 7

    class Serializer
      #########################################################################
      # Base seralization function
      #########################################################################

      def singular_plural
        @result = if @query[:single]
          @data[0]
        else
          { @resource => @data }
        end
      end

      def serialize(object, env)
        if (env['PATH_INFO'] =~ /^\/ngsi|swagger/)
          env['api.endpoint'].header 'Content-Type', 'application/json; charset=utf-8'
          env['api.endpoint'].header 'Access-Control-Allow-Origin', '*'
          object.to_json
        else
          if object.class == Hash
            @env = env
            @resource = object[:resource]
            @data = object[:data]
            @query = object[:query]
            @layers = object[:layers]
            @result = {}
            begin
              start
              send @resource
              finish
            rescue NoMethodError
              @query[:api].error!("Serialization error - #{@resource} not implemented for #{@query[:format]}.", 500)
            rescue Exception => e
              @query[:api].error!("Serialization error - #{e.message}; (data: #{@data}; resource: #{@resource}).", 500)
            end
          end
        end
      end
    end
  end
end
