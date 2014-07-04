# encoding: UTF-8

require_relative '../app/api_helpers.rb'

module CitySDKLD
  class Layers < Grape::API

    resource :layers do

      desc 'Return all layers'
      get '/' do
        do_query :layers
      end

      desc 'Create new layer',
      headers: {
        "X-Auth" => {
          description: "Admin or layer owner session key",
          required: true
        }
      }
      post '/' do
        do_query :layers, single: true
      end

      resource '/:layer', requirements: { layer: ::Helpers.alphanumeric_regex } do

        desc 'Return single layer'
        get '/' do
          do_query :layers, single: true
        end

        desc 'Edit a layer',
        headers: {
          "X-Auth" => {
            description: "Admin or layer owner session key",
            required: true
          }
        }
        patch '/' do
          do_query :layers, single: true
        end

        desc 'Delete a layer',
        headers: {
          "X-Auth" => {
            description: "Admin or layer owner session key",
            required: true
          }
        }
        delete '/' do
          do_query :layers
        end

        desc 'Return all owners associated with single layer'
        get '/owners' do
          do_query :owners
        end

        desc 'Return JSON-LD context of single layer'
        get '/@context' do
          do_query :context, single: true
        end

        desc 'Overwrite JSON-LD context of single layer',
        headers: {
          "X-Auth" => {
            description: "Admin or layer owner session key",
            required: true
          }
        }
        put '/@context' do
          do_query :context, single: true
        end

        resource :objects do

          desc 'Return all objects with data on single layer'
          get '/' do
            do_query :objects
          end

          desc 'Create one or more objects with data on single layer, or add data to existing objects (or a combination thereof)',
          headers: {
            "X-Auth" => {
              description: "Admin or layer owner session key",
              required: true
            }
          }
          post '/' do
            do_query :objects
          end

          desc 'Edit one or more objects and data on single layer',
          headers: {
            "X-Auth" => {
              description: "Admin or layer owner session key",
              required: true
            }
          }
          patch '/' do
            do_query :objects
          end

          resource '/:cdk_id', requirements: { cdk_id: ::Helpers.alphanumeric_regex } do
            desc 'Return metadata of single layer about single object, e.g. the date the data was added/modified, etc.'
            get '/' do
              do_query :layer_on_object, single: true
            end

          end
        end

        resource :fields do

          desc 'Return all fields of single layer'
          get '/' do
            do_query :fields
          end

          desc 'Create new field for single layer',
          headers: {
            "X-Auth" => {
              description: "Admin or layer owner session key",
              required: true
            }
          }
          post '/' do
            do_query :fields, single: true
          end

          desc 'Return single field of single layer'
          get '/:field' do
            do_query :fields, single: true
          end

          desc 'Overwrite single field on single layer',
          headers: {
            "X-Auth" => {
              description: "Admin or layer owner session key",
              required: true
            }
          }
          put '/:field' do
            do_query :fields, single: true
          end

          desc 'Edit single field on single layer',
          headers: {
            "X-Auth" => {
              description: "Admin or layer owner session key",
              required: true
            }
          }
          patch '/:field' do
            do_query :fields, single: true
          end

          desc 'Delete a single field on single layer',
          headers: {
            "X-Auth" => {
              description: "Admin or layer owner session key",
              required: true
            }
          }
          delete '/:field' do
            do_query :fields, single: true
          end

        end

      end

    end
  end
end
