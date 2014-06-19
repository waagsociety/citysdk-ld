# encoding: UTF-8

module CitySDKLD

  class App

    @config = JSON.parse(File.read("./config.#{ENV["RACK_ENV"]}.json"), symbolize_names: true)
    def self.get_config
      @config
    end

    def self.instance
      @instance ||= Rack::Builder.new do
        use Rack::Cors do
          allow do
            origins '*'
            resource '*', headers: :any, methods: :get
          end
        end

        run CitySDKLD::App.new
      end.to_app
    end

    def call(env)
      # Set request's content type to JSON, no matter what
      env['CONTENT_TYPE'] = 'application/json'
      CitySDKLD::API.call(env)
    end
  end
end
