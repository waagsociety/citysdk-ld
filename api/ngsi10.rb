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

      desc 'Query context broker for contextElements'
      post '/subscribeContext' do
        do_query :ngsi10
      end

      desc 'Query context broker for contextElements'
      post '/updateContextSubscription' do
        do_query :ngsi10
      end

      desc 'Query context broker for contextElements'
      post '/unsubscribeContext' do
        do_query :ngsi10
      end


    end

  end
end


