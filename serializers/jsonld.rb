# encoding: UTF-8

require_relative 'serializer.rb'
require_relative 'geojson.rb'

module CitySDKLD

  module Serializers

    class JSONLDSerializer < GeoJSONSerializer

      FORMAT = :jsonld
      CONTENT_TYPE = 'application/ld+json'

      def finish

        case @resource
        when :objects
          @result = {
            :@context => create_object_context,
            :@type => ':APIResult'
          }.merge @result

          jsonld_objects
        when :layers
          @result = {
            :@context => create_layer_context,
            :@type => ':APIResult'
          }.merge @result

          jsonld_layers
        end

        super
      end

      def jsonld_objects
        # TODO: add layer's fields to serialization

        first = true
        @result[:features].map! do |feature|
          cdk_id = feature[:properties][:cdk_id]
          feature[:properties] = {
            :@id => ":objects/#{cdk_id}"
          }.merge feature[:properties]

          feature[:properties][:layer] = ":layers/#{feature[:properties][:layer]}"

          if feature[:properties].key? :layers
            feature[:properties][:layers].each do |l,layer|

              layer[:layer] = ":layers/#{l}"

              layer = {
                :@id => ":layers/#{l}/objects/#{cdk_id}",
                :@type => ':LayerOnObject'
              }.merge layer

              context = "http://#{@query[:host]}/layers/#{l}/context"
              if first
                context = @layers[l][:context] if @layers[l][:context]
              end

              types = [':LayerData']
              types << @layers[l][:rdf_type] if @layers[l][:rdf_type]

              layer[:data] = {
                :@id => ":objects/#{cdk_id}/layers/#{l}",
                :@type => types,
                :@context => context
              }.merge layer[:data]

              feature[:properties][:layers][l] = layer
            end
          end

          first = false

          {
            :@id => ":objects/#{cdk_id}",
            :@type => ':Object'
          }.merge feature
        end
      end

      def jsonld_layers
        first_feature = true
        @result[:features].map! do |feature|
          feature[:properties] = {
            :@id => ":layers/#{feature[:properties][:name]}"
          }.merge feature[:properties]

          {
            :@id => ":layers/#{feature[:properties][:name]}",
            :@type => [":Layer", "dcat:Dataset"]
          }.merge feature
        end
      end

      # def layer_on_object
      #   # TODO: use
      #   #:imported_at => 'dcat:modified'
      # end

      def create_object_context
        endpoint_data = CitySDKLD.get_endpoint_data(@query)

        {
          :@vocab => endpoint_data[:base_uri],
        }.merge(CitySDKLD::PREFIXES).merge({
          title: 'dc:title',
          cdk_id: ':cdk_id',
          features: ':apiResult',
          properties: '_:properties',
          date_created: 'dc:date',
          layer: {
            :@id => ':createdOnLayer',
            :@type => '@id'
          },
          layers: {
            :@id => ':layerOnObject',
            :@container => '@index'
          },
          data: ':layerData',
          geometry: nil,
          type: nil
        })
      end

      def create_layer_context
        endpoint_data = CitySDKLD.get_endpoint_data(@query)

        {
          :@vocab => endpoint_data[:base_uri],
        }.merge(CitySDKLD::PREFIXES).merge({
          title: 'dcat:title',
          features: ':apiResult',
          properties: '_:properties',
          name: 'rdfs:label',
          title: 'dc:title',
          description: 'dc:description',
          category: {

          },
          subcategory: ':subcategory',
          geometry: nil,
          type: nil,


          # # rdf_type: {
          # #   :'@id' => '',
          # #   :'@type'=> '@id'
          # # }
          # licence
          # data_sources
          # fields
          # owner
        })



        # @layers.each do |l, layer|
        #   layer[:fields].each do |field|
        #     @result << "<layers/#{l}/fields/#{field[:id]}>"
        #     @result << "    :definedOnLayer <layers/#{l}> ;"
        #
        #     @result << "    rdf:type #{field[:type]} ;" if field[:type]
        #     @result << "    rdfs:description #{field[:description].to_json} ;" if field[:description]
        #     @result << "    xsd:language #{field[:lang].to_json} ;" if field[:lang]
        #     @result << "    owl:equivalentProperty #{field[:eqprop]} ;" if field[:eqprop]
        #     @result << "    :hasValueUnit #{field[:unit]} ;" if field[:unit]
        #
        #     @result << "    rdfs:subPropertyOf :layerProperty ."
        #     @result << ""
        #   end
        # end


        #
        # "licence": "http://www.openstreetmap.org/copyright",
        # "data_sources": [
        #
        #     "http://www.openstreetmap.org/"
        #
        # ],
        #
        # # NieT: "rdf_prefixes"
        #
        # "owner": {
        #
        #     "name": "citysdk",
        #     "fullname": "CitySDK",
        #     "email": "citysdk@waag.org",
        #     "organization": "CitySDK LD",
        #     "admin": true
        #
        # },
        # "fields": [


        #TODO: toevoegen prefixes
        #TODO: TYPE van het dataojbject!!!!!
      end

    end
  end
end
