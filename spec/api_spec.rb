# encoding: UTF-8

require 'spec_helper'

describe CitySDKLD::API do
  include Rack::Test::Methods

  def app
    CitySDKLD::API
  end

  def read_test_data(filename)
    File.read("./spec/data/#{filename}")
  end

  def read_test_data_json(filename)
    JSON.parse(read_test_data(filename), symbolize_names: true)
  end

  def body_json(last_response)
    JSON.parse(last_response.body, symbolize_names: true)
  end

  def compare_hash(h1, h2, skip_recursion = false)
    result = true
    h1.keys.each do |k|
      if h1[k] and h1[k] != ''
        result &= (h1[k] == h2[k])
      end
    end
    result &= compare_hash(h2, h1, true) unless skip_recursion
    result
  end

  describe CitySDKLD::API do

    ######################################################################
    # owners:
    ######################################################################

    describe "POST /owners" do
      it "creates owner 'bert'" do
        post "/owners", read_test_data('owner_bert.json')
        last_response.status.should == 201
        body_json(last_response)[:name].should == 'bert'
      end

      it "creates another owner 'bert' " do
        post "/owners", read_test_data('owner_bert.json')
        last_response.status.should == 422
        body_json(last_response).should == {error: "Owner already exists: bert"}
      end

      it "creates owner 'tom' with too simple password" do
        post "/owners", read_test_data('owner_tom.json').gsub('ABCabc456','nix')
        last_response.status.should == 422
        body_json(last_response).should == {error: 'Password needs to be longer, or contain numbers, capitals or symbols'}
      end

      it "creates owner 'tom' " do
        post "/owners", read_test_data('owner_tom.json')
        last_response.status.should == 201
        body_json(last_response)[:name].should == 'tom'
      end

      it "creates owner 'rutger' " do
        post "/owners", read_test_data('owner_rutger.json')
        last_response.status.should == 201
        body_json(last_response)[:name].should == 'rutger'
      end

      it "creates owner '[tom]' " do
        data = read_test_data_json 'owner_tom.json'
        data[:name] = '[tom]'
        post "/owners", data.to_json
        last_response.status.should == 422
        body_json(last_response).should == {error: "'name' can only contain alphanumeric characters, underscores and periods"}
      end
    end

    describe "PATCH /owners/bert" do
      it "edits owner 'bert' " do
        fullname = 'Bert “😩” Spaan'
        patch "/owners/bert", {fullname: fullname}.to_json
        last_response.status.should == 200
        body_json(last_response)[:fullname].should == fullname
      end
    end

    describe "PATCH /owners/tom" do
      it "edits owner 'tom' " do
        website = 'http://demeyer.nl/Lembeh-2014'
        patch "/owners/tom", {website: website}.to_json
        last_response.status.should == 200
        body_json(last_response)[:website].should == website
      end

      it "edits name of owner 'tom''" do
        data = read_test_data_json 'owner_tom.json'
        data[:name] = 'tommie'
        patch "/owners/tom", data.to_json
        last_response.status.should == 422
        body_json(last_response).should == {error: "Owner name cannot be changed"}
      end
    end

    describe "GET /owners" do
      it "gets all created owners and default owner 'citysdk'" do
        expected_owners = ['tom', 'bert', 'rutger', 'citysdk']
        get "/owners"
        last_response.status.should == 200
        data = body_json(last_response)
        data.length.should == expected_owners.length
        (data.map { |owner| owner[:name] } - expected_owners).blank?.should == true
      end
    end

    describe "GET /owners/tommie" do
      it "gets owner that doesn't exist" do
        get "/owners/tommie"
        last_response.status.should == 404
      end
    end

    describe "GET /owners/bert" do
      # TODO: get single owner: turtle, json, etc.
    end

    ######################################################################
    # layers:
    ######################################################################

    describe "POST /layers" do
      it "creates layer 'bert.dierenwinkels'" do
        data = read_test_data_json 'layer_bert.dierenwinkels.json'
        data.delete(:fields)
        data.delete(:context)
        post "/layers", data.to_json
        last_response.status.should == 201
        body_json(last_response)[:features][0][:properties][:name].should == 'bert.dierenwinkels'
      end

      it "creates layer 'tom.achtbanen'" do
        post "/layers", read_test_data('layer_tom.achtbanen.json')
        last_response.status.should == 201
        body_json(last_response)[:features][0][:properties][:name].should == 'tom.achtbanen'
      end

      it "creates layer 'tom.steden'" do
        post "/layers", read_test_data('layer_tom.steden.json')
        last_response.status.should == 201
        body_json(last_response)[:features][0][:properties][:name].should == 'tom.steden'
      end

      it "creates layer 'rutger.openingstijden'" do
        post "/layers", read_test_data('layer_rutger.openingstijden.json')
        last_response.status.should == 201
        body_json(last_response)[:features][0][:properties][:name].should == 'rutger.openingstijden'
      end
    end

    describe "PATCH /layers/bert.dierenwinkels" do
      it "edits layer 'bert.dierenwinkels' " do
        title = 'Alle dierenwinkels in Nederland - 🐢🐭🐴'
        patch "/layers/bert.dierenwinkels", {title: title}.to_json
        last_response.status.should == 200
        body_json(last_response)[:features][0][:properties][:title].should == title
      end
    end

    describe "GET /layers" do
      it "gets all layers" do
        expected_layers = [
          'bert.dierenwinkels', 'rutger.openingstijden',
          'tom.achtbanen', 'tom.steden'
        ]
        get "/layers"
        last_response.status.should == 200
        data = body_json(last_response)
        data[:features].length.should == expected_layers.length
        (data[:features].map { |layer| layer[:properties][:name] } - expected_layers).blank?.should == true
      end
    end

    describe "GET /layers/bert.achtbanen" do
      it "gets layer that doesn't exist" do
        get "/layers/bert.achtbanen"
        last_response.status.should == 404
      end
    end

    describe "GET /layer/bert.dierenwinkels" do
      # TODO: get single owner: turtle, json, etc.
    end

    ######################################################################
    # context:
    ######################################################################

    describe "GET /layers/tom.achtbanen/context" do
      it "gets JSON-LD context of layer 'tom.achtbanen'" do
        data = read_test_data_json 'layer_tom.achtbanen.json'
        get "/layers/tom.achtbanen/context"
        last_response.status.should == 200
        body_json(last_response).should == data[:context]
      end
    end

    describe "GET /layers/bert.dierenwinkels/context" do
      it "gets JSON-LD context of layer 'bert.dierenwinkels'" do
        get "/layers/bert.dierenwinkels/context"
        last_response.status.should == 200
        body_json(last_response).should == {}
      end
    end

    describe "PUT /layers/bert.dierenwinkels/context" do
      it "sets JSON-LD context of layer 'bert.dierenwinkels'" do
        data = read_test_data_json 'layer_bert.dierenwinkels.json'
        put "/layers/bert.dierenwinkels/context", data[:context].to_json
        last_response.status.should == 200
        body_json(last_response).should == data[:context]
      end
    end

    describe "GET /layer/bert.dierenwinkels/context" do
      # TODO: get single context: turtle, json, etc.
      # TODO: Not accepted for Turtle!
    end

    ######################################################################
    # fields:
    ######################################################################

    describe "GET /layers/tom.achtbanen/fields" do
      it "gets fields of layer 'tom.achtbanen'" do
        data = read_test_data_json 'layer_tom.achtbanen.json'
        get "/layers/tom.achtbanen/fields"
        last_response.status.should == 200
        body_json(last_response).length.should == data[:fields].length
      end
    end

    describe "POST /layers/bert.dierenwinkels/fields" do
      it "creates multiple fields for layer 'bert.dierenwinkels'" do
        data = read_test_data_json 'layer_bert.dierenwinkels.json'
        data[:fields].each do |field|
          post "/layers/bert.dierenwinkels/fields", field.to_json
          last_response.status.should == 201
          compare_hash(body_json(last_response), field).should == true
        end
      end

      it "creates single field for layer 'bert.dierenwinkels'" do
        field = {
          name: "field",
          description: "Dit is een nepveld!"
        }
        post "/layers/bert.dierenwinkels/fields", field.to_json
        last_response.status.should == 201
        body_json(last_response).should == field
      end
    end

    describe "PATCH /layers/bert.dierenwinkels/fields/field" do
      it "edits single field 'field' for layer 'bert.dierenwinkels'" do
        field = {
          name: "field",
          description: "Dit is een nepveld!",
          lang: "nl"
        }
        patch "/layers/bert.dierenwinkels/fields/field", {lang: field[:lang]}.to_json
        last_response.status.should == 200
        body_json(last_response).should == field
      end
    end

    describe "DELETE /layers/bert.dierenwinkels/fields/field" do
      it "deletes single field 'field' for layer 'bert.dierenwinkels'" do
        delete "/layers/bert.dierenwinkels/fields/field"
        last_response.status.should == 204
        last_response.body.should == ''
      end
    end

    describe "GET /layers/bert.dierenwinkels/fields" do
      it "gets fields of layer 'bert.dierenwinkels'" do
        data = read_test_data_json 'layer_bert.dierenwinkels.json'
        get "/layers/bert.dierenwinkels/fields"
        last_response.status.should == 200
        body_json(last_response).length.should == data[:fields].length
      end
    end

    describe "GET /layers/tom.achtbanen/fields/lengte" do
      it "gets 'lengte' field of layer 'tom.achtbanen'" do
        get "/layers/tom.achtbanen/fields/lengte"
        last_response.status.should == 200
        # TODO serializaties
      end
    end

    ######################################################################
    # objects + data:
    ######################################################################

    describe "POST /layers/bert.dierenwinkels/objects" do
      it "creates objects and data on layer 'bert.dierenwinkels'" do
        data = read_test_data_json 'objects_bert.dierenwinkels.json'
        data = {
          type: "FeatureCollection",
          features: data[:features][0..-2]
        }
        post "/layers/bert.dierenwinkels/objects", data.to_json
        last_response.status.should == 201
        body_json(last_response).length.should == data[:features].length
      end

      it "creates single object with data on layer 'bert.dierenwinkels'" do
        data = read_test_data_json 'objects_bert.dierenwinkels.json'
        data = data[:features][-1]
        post "/layers/bert.dierenwinkels/objects", data.to_json
        last_response.status.should == 201
        body_json(last_response).length.should == 1
      end

      it "creates single object without geometry" do
        data = read_test_data_json 'objects_bert.dierenwinkels.json'
        data = data[:features][-1]
        data.delete(:geometry)
        post "/layers/bert.dierenwinkels/objects", data.to_json
        last_response.status.should == 422
        body_json(last_response).should == {error: "New object without geometry encountered"}
      end

      it "creates single object with GeometryCollection" do
        data = read_test_data_json 'objects_bert.dierenwinkels.json'
        data = data[:features][-1]
        data[:geometry] = {
          type: "GeometryCollection",
          geometries: [
            {
              type: "Point",
              coordinates: [5.16521, 52.22154]
            },
            {
              type: "LineString",
              coordinates: [
                [4.8423, 52.21213], [4.5321, 52.12132]
              ]
            }
          ]
        }
        post "/layers/bert.dierenwinkels/objects", data.to_json
        body_json(last_response).should == {error: "GeoJSON GeometryCollections are not allowed as object geometry"}
      end

      it "creates single object with invalid GeoJSON geometry" do
        data = read_test_data_json 'objects_bert.dierenwinkels.json'
        data = data[:features][-1]
        data[:geometry] = {
          type: "SuperPoint",
          coordinates: [5.16521, 52.22154]
        }
        post "/layers/bert.dierenwinkels/objects", data.to_json
        body_json(last_response).should == {error: "Invalid GeoJSON geometry encountered"}
      end

      it "creates single object with 3D Point geometry" do
        data = read_test_data_json 'objects_bert.dierenwinkels.json'
        data = data[:features][-1]
        data[:geometry] = {
          type: "Point",
          coordinates: [5.16521, 52.22154, -1]
        }
        post "/layers/bert.dierenwinkels/objects", data.to_json
        body_json(last_response).should == {error: "Geometry has Z dimension but column does not"}
      end

      # TODO: zonder id
      # TODO: met cdk_id
    end

    describe "POST /layers/bert.bioscopen/objects" do
      it "creates objects and data on layer that doesn't exist" do
        post "/layers/bert.bioscopen/objects", read_test_data('objects_bert.dierenwinkels.json')
        last_response.status.should == 404
        body_json(last_response).should == {error: "Layer not found: 'bert.bioscopen'"}
      end
    end

    describe "POST /layers/tom.achtbanen/objects" do
      it "creates objects and data on layer 'tom.achtbanen'" do
        data = read_test_data_json 'objects_tom.achtbanen.json'
        post "/layers/tom.achtbanen/objects", data.to_json
        last_response.status.should == 201
        body_json(last_response).length.should == data[:features].length
      end
    end

    describe "POST /layers/tom.steden/objects" do
      it "creates objects and data on layer 'tom.steden'" do
        data = read_test_data_json 'objects_tom.steden.json'
        post "/layers/tom.steden/objects", data.to_json
        last_response.status.should == 201
        body_json(last_response).length.should == data[:features].length
      end
    end

    describe "POST /layers/rutger.openingstijden/objects" do
      it "adds data on layer 'rutger.openingstijden' to existing objects" do
        data = read_test_data_json 'objects_rutger.openingstijden.json'
        post "/layers/rutger.openingstijden/objects", data.to_json
        last_response.status.should == 201
        body_json(last_response).length.should == data[:features].length
      end

      # TODO: Voeg data toe aan cdk_id dat niet bestaat!
      # TODO: voeg data toe aan bestaand cdk_id met ook geometry/titel
    end

    # Edit data
    # Edit objects (geom/title)
    # check layer bounding box
    # check serializations
    # bekijk losse objecten
    # bekijk velden
    # bekijk alle serialisaties
    # bekijk metadata

    ######################################################################
    # filters:
    ######################################################################

    # All filters:
    # [cdk_id:, layer:, owner:, field:, in:, contains:, bbox:, nearby:, name:, data:]


    # nearby
    # http://localhost:9292/objects?lat=52.37277&lon=4.90033
    # http://localhost:9292/objects?lat=52.37277&lon=4.90033&radius=10000


    # in
    #http://localhost:9292/layers/tom.achtbanen/objects?in=tom.steden.utrecht
    # moet zijn cdk_id tom.achtbanen.4

    # contains:
    # http://localhost:9292/objects?contains=tom.achtbanen.4
    # http://localhost:9292/layers/tom.steden/objects?contains=tom.achtbanen.4
    # MOET ZIJN tom.steden.utrecht

    # name

    # bbox

    #filter: icon": "🐟",
    # http://localhost:9292/objects?bert.dierenwinkels::icon=🐟
    # wordt geoede gevonden, en komt data ook mee?
    # http://localhost:9292/objects?bert.dierenwinkels::type=geleedpotigen

    # layer = *

    # pagination headers - layers, objects!
    # count!


    ######################################################################
    # endpoint:
    ######################################################################

    describe "GET /" do
      it "gets endpoint status" do
        get "/"
        last_response.status.should == 200
        # TODO: check endpoint content
      end
    end

    ######################################################################
    # miscellaneous:
    ######################################################################

    describe "GET /layers/tom.achtbanen/owners" do
      it "gets owners of layer 'tom.achtbanen'" do
        get "/layers/tom.achtbanen/owners"
        last_response.status.should == 200
        # TODO: check content
      end
    end

    describe "GET /owners/tom/layers" do
      it "gets layers of owner 'tom'" do
        get "/owners/tom/layers"
        last_response.status.should == 200
        # TODO: check content
      end
    end

    ######################################################################
    # and now... delete everything:
    ######################################################################

    # TODO: verwijder single object

    describe "DELETE /layers/bert.dierenwinkels" do
      it "deletes layer 'bert.dierenwinkels'" do
        delete "/layers/bert.dierenwinkels"
        last_response.status.should == 204
        last_response.body.should == ''

        # Rutgers dingen moeten er nog zijn, en objecten op laag 'none'
        # Tel rutgers objecten
      end
    end

    describe "DELETE /owners/rutger" do
      it "deletes owner 'rutger'" do
        delete "/owners/rutger"
        last_response.status.should == 204
        last_response.body.should == ''

        # ook objecten die op laag none zitten moeten nu weg zijn
      end
    end

    describe "DELETE /owners/bert" do
      it "deletes owner 'bert'" do
        delete "/owners/bert"
        last_response.status.should == 204
        last_response.body.should == ''
      end
    end

    describe "DELETE /owners/tom" do
      it "deletes owner 'tom'" do
        delete "/owners/tom"
        last_response.status.should == 204
        last_response.body.should == ''
      end
    end

  end
end