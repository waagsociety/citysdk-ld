# encoding: UTF-8

module CitySDKLD
  class Endpoints < Grape::API

    desc 'Return current endpoint status'
    get '/' do
      do_query :endpoints, true
    end

  end
end
