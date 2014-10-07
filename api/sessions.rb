# encoding: UTF-8

module CitySDKLD
  class Sessions < Grape::API

    desc 'Return a session key'
    params do
      requires :name, type: String, desc: "Login name."
      requires :password, type: String, desc: "Login password."
    end
    get '/session' do
      do_query :sessions, true
    end

    desc 'Close session'
    delete '/session' do
      do_query :sessions
    end

  end
end
