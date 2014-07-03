# encoding: UTF-8

module CitySDKLD
  class Sessions < Grape::API

    desc 'Return a session key'
    get '/session' do
      do_query :sessions, single: true
    end

    desc 'Return a session key'
    delete '/session' do
      do_query :sessions
    end

  end
end
