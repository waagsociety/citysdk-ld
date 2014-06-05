# encoding: UTF-8

module CitySDKLD
  class Layers < Grape::API

    resource :layers do

      desc 'Return all layers'
      get '/' do
        do_query :layers
      end

      desc 'Create new layer'
      post '/' do
        do_query :layers, single: true
      end

      # TODO: get regex from Layer model class
      resource '/:layer', requirements: { layer: /\w+(\.\w+)*/ } do

        desc 'Return single layer'
        get '/' do
          do_query :layers, single: true
        end

        # curl --request PATCH --data "{\"title\":\"Alle dierenwinkels in Nederland\"}" http://localhost:9292/layers/bert.dierenwinkels
        # curl --request PATCH --data "{\"owner\":\"tom\"}" http://localhost:9292/layers/poi.hotels
        desc 'Edit a layer'
        patch '/' do
          do_query :layers, single: true
        end

        # TODO: deze nog maken
        desc 'Delete a layer'
        delete '/' do
          do_query :layers
        end

        desc 'Return all owners associated with single layer'
        get '/owners' do
          do_query :owners
        end

        desc 'Return JSON-LD context of single layer'
        get '/context' do
          do_query :context, single: true
        end

        # curl -X PUT --data "{\"rooms\":\"xsd:integer\"}" http://localhost:9292/layers/poi.hotels/context
        desc 'Overwrite JSON-LD context of single layer'
        put '/context' do
          do_query :context, single: true
        end

        resource :objects do

          desc 'Return all objects with data on single layer'
          get '/' do
            do_query :objects
          end

          # Add two objects + data:
          #   curl --data "{\"type\":\"FeatureCollection\",\"features\":[{\"type\":\"Feature\",\"properties\":{\"id\":\"1\",\"title\":\"Vissenwinkel Jos\",\"data\":{\"name\":\"Vissenwinkel Jos\", \"type\": \"vissen\"}},\"geometry\":{\"type\":\"Point\",\"coordinates\":[4.89396,52.371127]}},{\"type\":\"Feature\",\"properties\":{\"id\":\"2\",\"title\":\"De Kikkerspeciaalzaak\",\"data\":{\"name\": \"De Kikkerspeciaalzaak\", \"type\":\"amfibieën\"}},\"geometry\":{\"type\":\"Point\",\"coordinates\":[4.89346,52.371027]}}]}" http://localhost:9292/layers/bert.dierenwinkels/objects
          # Add one new object + data, and add data to one existing object:
          #   curl --data "{\"type\":\"FeatureCollection\",\"features\":[{\"type\":\"Feature\",\"properties\":{\"cdk_id\":\"w74171331\",\"data\":{\"type\":\"theatre\"}}},{\"type\":\"Feature\",\"properties\":{\"id\":\"3\",\"name\":\"De Vis\",\"data\":{\"type\":\"cinema\"}},\"geometry\":{\"type\":\"Point\",\"coordinates\":[4.49346,52.271027]}}]}" http://localhost:9292/layers/bert.spaan/objects
          desc 'Create one or more objects with data on single layer, or add data to existing objects (or a combination thereof)'
          post '/' do
            do_query :objects
          end

          # curl --request PATCH --data "{\"type\":\"FeatureCollection\",\"features\":[{\"type\":\"Feature\",\"properties\":{\"cdk_id\":\"w74171325\",\"data\":{\"type\":\"theatre\"}}},{\"type\":\"Feature\",\"properties\":{\"cdk_id\":\"w74171331\",\"data\":{\"type\":\"cinema\"}}}]}" http://localhost:9292/layers/bert.spaan/objects
          desc 'Edit one or more objects and data on single layer'
          patch '/' do
            do_query :objects
          end

          resource '/:cdk_id', requirements: { layer: /\w+(\.\w+)*/ } do
            # TODO: layer_on_object verteld ook of :layer de laag is van object zelf.??
            # dus het verteld alles over –relatie_ van object met laag, is er data, dit en dat.??
            desc 'Return metadata of single layer about single object, e.g. the date the data was added/modified, etc.'
            get '/' do
              do_query :layer_on_object, single: true
            end

          end

        end

        resource :fields do

          desc 'Return all fields of single layer'
          get '/' do
            do_query :fields
          end

          # curl --data "{\"name\": \"name\", \"type\": \"xsd:string\", \"description\": \"Naam van de dierenwinkel\", \"equivalentProperty\": \"dc:title\"}" http://localhost:9292/layers/bert.dierenwinkels/fields
          desc 'Create new field for single layer'
          post '/' do
            do_query :fields, single: true
          end

          desc 'Return single field of single layer'
          get '/:field' do
            do_query :fields, single: true
          end

          # curl -X PUT --data "{\"type\": \"xsd:string\", \"description\": \"Name of administrative region\", \"equivalentProperty\": \"dc:description\"}" http://localhost:9292/layers/admr/fields/name
          desc 'Overwrite single field on single layer'
          put '/:field' do
            do_query :fields, single: true
          end

          # curl --request PATCH --data "{\"description\": \"Name of the administrative region\"}" http://localhost:9292/layers/admr/fields/name
          desc 'Edit single field on single layer'
          patch '/:field' do
            do_query :fields, single: true
          end

          # curl -X DELETE http://localhost:9292/layers/admr/fields/name
          desc 'Delete a single field on single layer'
          delete '/:field' do
            do_query :fields, single: true
          end

        end

      end

    end
  end
end
