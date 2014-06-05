# encoding: UTF-8

module CitySDKLD
  class Objects < Grape::API

    resource :objects do

      desc 'Return all objects'
      get '/' do
        do_query :objects
      end

      # TODO: get regex from Object model class
      resource '/:cdk_id', requirements: { cdk_id: /\w+(\.\w+)*/ } do

        desc 'Get a single object'
        get '/' do
          do_query :objects, single: true
        end

        # # TODO: deze nog maken!
        # desc 'Edit a single object'
        # patch '/' do
        #   do_query :objects
        # end
        #
        # # TODO: deze nog maken!
        # desc 'Delete a single object'
        # delete '/' do
        #   do_query :objects
        # end

        resource :layers do

          desc 'Get all layers that contain data of single object'
          get '/' do
            do_query :layers
          end

          resource '/:layer', requirements: { layer: /\w+(\.\w+)*/ } do

            desc 'Return all data on single layer of single object'
            get '/' do
              do_query :data, single: true
            end

            # curl --data "{\"url\": \"http://vis.com/hond\"}" http://localhost:9292/objects/n46127914/layers/artsholland
            desc 'Add data on layer to single object'
            post '/' do
              do_query :data, single: true
            end

            # curl -X PUT --data "{\"chips\": \"nee\"}" http://localhost:9292/objects/n46127914/layers/artsholland
            desc 'Overwrite data on layer to single object'
            put '/' do
              do_query :data, single: true
            end

            # curl --request PATCH --data "{\"url\": \"http://bertspaan.nl/\"}" http://localhost:9292/objects/n46127914/layers/artsholland
            desc 'Update data on layer to single object'
            patch '/' do
              do_query :data, single: true
            end

            # curl -X DELETE http://localhost:9292/objects/n46127914/layers/artsholland
            desc 'Remove data on layer from single object'
            delete '/' do
              do_query :data
            end

          end

        end

      end

    end

  end

end
