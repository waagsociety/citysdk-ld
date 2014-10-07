# encoding: UTF-8

require_relative '../app/api_helpers.rb'

module CitySDKLD
  class Owners < Grape::API

    resource :owners do

      desc 'Return all owners'
      get '/' do
        do_query :owners
      end

     desc 'Create new owner'
      post '/' do
        do_query :owners, true
      end

      resource '/:owner', requirements: { owner: ::Helpers.alphanumeric_regex } do

        desc 'Get a single owner'
        get '/' do
          do_query :owners, true
        end

        desc 'Edit an owner'
        patch '/' do
          do_query :owners, true
        end

        desc 'Delete owner - and all layers and data belonging to this owner'
        delete '/' do
          do_query :owners
        end

        desc 'Return all layers belonging to a single owner'
        get '/layers' do
          do_query :layers
        end

      end

    end
  end
end
