# encoding: UTF-8

require_relative '../app/api_helpers.rb'

module CitySDKLD

  class NGSI10 < Grape::API

    resource :ngsi10 do

      desc 'Add or update NGSI contextElements'
      post '/updateContext' do
        do_query :ngsi10
      end

      desc 'Query context broker for contextElements'
      post '/queryContext' do
        do_query :ngsi10
      end

      desc 'Create a new context subscription'
      post '/subscribeContext' do
        do_query :ngsi10
      end

      desc 'Update/edit a context subscription'
      post '/updateContextSubscription' do
        do_query :ngsi10
      end

      desc 'Delete a context subscription'
      post '/unsubscribeContext' do
        do_query :ngsi10
      end

      resource :contextEntityTypes do

        desc 'Return objects of particular type'
        get '/:cetype' do
          do_query :ngsi10, true
        end

        desc 'Return objects of particular type'
        get '/:cetype/attributes/:attribute' do
          do_query :ngsi10, true
        end

      end



      resource :contextEntities do

        resource '/:entity', requirements: { entity: ::Helpers.alphanumeric_regex } do

          desc 'Return single context entity'
          get '/' do
            do_query :ngsi10, true
          end

          desc 'Update attributes for single context entity'
          put '/attributes' do
            do_query :ngsi10, true
          end

          desc 'Return single context entity attribute'
          get '/attributes/:attribute', requirements: { attribute: ::Helpers.alphanumeric_regex } do
            do_query :ngsi10, true
          end

        end

      end

    end

  end

end


