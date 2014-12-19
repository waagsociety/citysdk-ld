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
          # geojson, result is JSON object with features array
          @result = {
            :@context => create_object_context
          }.merge @result

          jsonld_objects
        when :layers
          # geojson, result is JSON object with features array
          @result = {
            :@context => create_layer_context
          }.merge @result

          jsonld_layers
        when :owners
          # either single owner, or JSON object with owners array
          @result = {
            :@context => create_owner_context
          }.merge @result

          jsonld_owners
        when :fields
          # either single field, or JSON object with fields array
          @result = {
            :@context => create_field_context
          }.merge @result

          jsonld_fields
        when :data
          # single data object
          endpoint_data = CitySDKLD.get_endpoint_data(@query)
          @result = {
            :@context => @layers.values[0][:context],
            :@id => "#{endpoint_data[:url]}objects/#{@query[:params][:cdk_id]}/layers/#{@query[:params][:layer]}",
            :@type => [
              "#{endpoint_data[:base_uri]}LayerData",
              @layers.values[0][:rdf_type]
            ]
          }.merge @result
        when :layer_on_object
          # single layer_on_data object
          endpoint_data = CitySDKLD.get_endpoint_data(@query)
          @result = {
            :@context => create_default_context({
              created_at: "dcat:issued",
              updated_at: "dcat:modified"
            }),
            :@id => "layers/#{@query[:params][:layer]}/objects/#{@query[:params][:cdk_id]}",
            :@type => "LayerOnObject"
          }.merge @result
        when :endpoints
          # single endpoint object in features array
          @result = {
            :@context => create_endpoint_context
          }.merge @result

          jsonld_endpoints
        end

        super
      end

      def jsonld_objects
        first = true
        @result[:features].map! do |feature|
          cdk_id = feature[:properties][:cdk_id]
          feature[:properties] = {
            :@id => "objects/#{cdk_id}"
          }.merge feature[:properties]

          feature[:properties][:layer] = "layers/#{feature[:properties][:layer]}"

          if feature[:properties].key? :layers
            feature[:properties][:layers].each do |l,layer|

              layer[:layer] = "layers/#{l}"

              layer = {
                :@id => "layers/#{l}/objects/#{cdk_id}",
                :@type => 'LayerOnObject'
              }.merge layer

              context = "http://#{@query[:host]}/layers/#{l}/context"
              if first
                context = @layers[l][:context] if @layers[l][:context]
              end

              types = ['LayerData']
              types << @layers[l][:rdf_type] if @layers[l][:rdf_type]

              layer[:data] = {
                :@id => "objects/#{cdk_id}/layers/#{l}",
                :@type => types,
                :@context => context
              }.merge layer[:data]

              feature[:properties][:layers][l] = layer

            end
          end

          first = false

          {
            :@id => "objects/#{cdk_id}",
            :@type => 'Object'
          }.merge feature
        end
      end

      def jsonld_layers
        @result[:features].map! do |feature|
          feature[:properties] = {
            :@id => "layers/#{feature[:properties][:name]}"
          }.merge feature[:properties]

          feature[:properties][:fields].map! do |field|
            "layers/#{feature[:properties][:name]}/fields/#{field}"
          end

          feature[:properties][:category] = "cdk:Category#{feature[:properties][:category].capitalize}"
          feature[:properties][:owner] = "owners/#{feature[:properties][:owner]}"

          if feature[:properties].has_key? :dependsOn
            feature[:properties][:dependsOn] = "layers/#{feature[:properties][:dependsOn]}"
          end

          {
            :@id => "layers/#{feature[:properties][:name]}",
            :@type => ['Layer', 'dcat:Dataset']
          }.merge feature
        end
      end

      def jsonld_owners
        if @query[:single]
          @result = {
            :@id => "owners/#{@result[:name]}",
          }.merge @result
          @result[:@type] = 'Owner'
        else
          @result[:owners].map! do |owner|
            {
              :@id => "owners/#{owner[:name]}",
              :@type => 'Owner'
            }.merge owner
          end
        end
      end

      def jsonld_fields
        layer = @query[:params][:layer]
        if @query[:single]
          @result = {
            :@id => "layers/#{layer}/fields/#{@result[:name]}",
          }.merge @result
          @result[:@type] = 'Field'
        else
          @result[:fields].map! do |field|
            {
              :@id => "layers/#{layer}/fields/#{field[:name]}",
              :@type => 'Field'
            }.merge field
          end
        end
      end

      def jsonld_endpoints
        endpoint_data = CitySDKLD.get_endpoint_data(@query)
        @result[:features][0][:properties] = {
          :@id => endpoint_data[:url],
          :@type => 'Endpoint'
        }.merge @result[:features][0][:properties]
      end

      def create_default_context(context)
          # Add LD prefixes
        endpoint_data = CitySDKLD.get_endpoint_data(@query)
        {
          :@base => endpoint_data[:url],
          :@vocab => endpoint_data[:base_uri],
          cdk: endpoint_data[:base_uri]
        }.merge(CitySDKLD::PREFIXES).merge(context)
      end

      def create_object_context
        create_default_context({
          title: 'dc:title',
          cdk_id: 'cdk_id',
          features: '_:features',
          properties: '_:properties',
          date_created: 'dc:date',
          layer: {
            :@id => 'createdOnLayer',
            :@type => '@id'
          },
          layers: {
            :@id => 'layerOnObject',
            :@container => '@index'
          },
          data: 'layerData',
          geometry: nil,
          type: nil
        })
      end

      def create_layer_context
        create_default_context({
          features: '_:features',
          properties: '_:properties',
          name: 'rdfs:label',
          title: 'dc:title',
          description: 'dc:description',
          geometry: nil,
          type: nil,
          context: nil,
          rdf_prefixes: nil,
          owner: {
            :@type => '@id'
          },
          dependsOn: {
            :@type => '@id'
          },
          category: {
            :@type => '@id'
          },
          rdf_type: {
            :@id => 'layerOnObjectType',
            :@type => '@id'
          },
          data_sources: 'dataSource',
          webservice_url: 'webServiceUrl',
          fields: {
            :@id => 'field',
            :@type => '@id'
          }
        })
      end

      def create_owner_context
        create_default_context({
          name: 'rdfs:label',
          fullname: 'foaf:name',
          email: 'foaf:mbox',
          admin: 'isAdmin',
          website: 'foaf:homepage',
          organization: 'organizationName',
          owners: '_:owners'
        })
      end

      def create_field_context
        create_default_context({
          name: 'rdfs:label',
          type: {
            :@id => 'fieldType',
            :@type => '@id'
          },
          unit: 'unit',
          lang: 'dc:language',
          equivalent_property: 'owl:equivalentProperty',
          description: 'dc:description',
          fields: '_:fields'
        })
      end

      def create_endpoint_context
        endpoint_data = CitySDKLD.get_endpoint_data(@query)
        @result = {
          :@context => create_default_context({
            features: '_:features',
            properties: '_:properties',
            name: 'rdfs:label',
            title: 'dc:title',
            description: 'dc:description',
            geometry: nil,
            urls: nil,
            type: nil,
            url: 'endpointUrl',
            swagger: 'swaggerUrl',
            base_uri: 'baseUri',
            organization: 'organizationName',
            homepage: 'foaf:homepage',
            email: 'foaf:mbox',
            github: 'githubUrl',
            wiki: 'wikiUrl'
          })
        }.merge @result
      end

    end
  end
end
