# encoding: UTF-8

module CitySDKLD
  class Sessions < Grape::API

    desc 'Return a session key'
    params do
      requires :name, type: String, desc: "Login name."
      requires :password, type: String, desc: "Login password."
    end
    get '/session' do
      do_query :sessions, single: true
    end

    desc 'Close session',
    headers: {
      "X-Auth" => {
        description: "Session key of session to close",
        required: true
      }
    }
    delete '/session' do
      do_query :sessions
    end

  end
end
