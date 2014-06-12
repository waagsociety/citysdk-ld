# encoding: UTF-8

require_relative '../app/api_helpers.rb'

module CitySDKLD

  class Objects < Grape::API

    resource :objects do

      desc 'Return all objects'
      get '/' do
        do_query :objects
      end

      resource '/:cdk_id', requirements: { cdk_id: ::Helpers.alphanumeric_regex } do

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

        desc 'Delete a single object'
        delete '/' do
          do_query :objects
        end

        resource :layers do

          desc 'Get all layers that contain data of single object'
          get '/' do
            do_query :layers
          end

          resource '/:layer', requirements: { layer: ::Helpers.alphanumeric_regex } do

            desc 'Return all data on single layer of single object'
            get '/' do
              do_query :data, single: true
            end

            desc 'Add data on layer to single object'
            post '/' do
              do_query :data, single: true
            end

            desc 'Overwrite data on layer to single object'
            put '/' do
              do_query :data, single: true
            end

            desc 'Update data on layer to single object'
            patch '/' do
              do_query :data, single: true
            end

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
