#encoding: utf-8

require 'spec_helper'
include Rack::Test::Methods

describe CitySDKLD::API do

  # TODO: refactor tests - combine multiple decribe/it blocks which
  # belong to one single 'task'.

  # The CitySDK LD API only sets the Content-Type header of all requests
  # to 'application/json' before invoking any API code, in the API's call function.
  # This does not seem to work for rspec's API calls, setting
  #   header "CONTENT_TYPE", "application/json"
  # is still needed in the tests.

  ######################################################################
  # owners:
  ######################################################################

  describe "GET /session" do
    it "gets a session key for owner 'citysdk'" do
      header "CONTENT_TYPE", "application/json"
      get "/session?name=citysdk&password=ChangeMeNow"
      status_should(last_response, 200)
      $key_citysdk = body_json(last_response)[:session_key]
      $key_citysdk.should_not == nil
    end
  end

  describe "POST /owners" do

    it "creates owner 'bert' without authorization" do
      header "CONTENT_TYPE", "application/json"
      post "/owners", read_test_data('owner_bert.json')
      status_should(last_response, 401)
      body_json(last_response).should == {error: "Operation requires administrative authorization"}
    end


    it "creates owner 'bert'" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_citysdk
      post "/owners", read_test_data('owner_bert.json')
      status_should(last_response, 201)
      body_json(last_response)[:name].should == 'bert'
    end

    it "gets a session key for owner 'bert'" do
      header "CONTENT_TYPE", "application/json"
      get "/session?name=bert&password=abcABC123"
      status_should(last_response, 200)
      $key_bert = body_json(last_response)[:session_key]
      $key_bert.should_not == nil
    end

    it "creates another owner 'bert' " do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_citysdk
      post "/owners", read_test_data('owner_bert.json')
      status_should(last_response, 422)
      body_json(last_response).should == {error: "Owner already exists: bert"}
    end

    it "creates owner 'tom' with a too simple password" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_citysdk
      post "/owners", read_test_data('owner_tom.json').gsub('ABCabc456', 'nix')
      status_should(last_response, 422)
      body_json(last_response).should == {error: 'Password needs to be longer, or contain numbers, capitals or symbols'}
    end

    it "creates owner 'tom'" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_citysdk
      post "/owners", read_test_data('owner_tom.json')
      status_should(last_response, 201)
      body_json(last_response)[:name].should == 'tom'
    end

    it "creates owner 'tom' without admin authorization" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_bert
      post "/owners", read_test_data('owner_tom.json')
      status_should(last_response, 401)
      body_json(last_response).should == {error: "Operation requires administrative authorization"}
    end

    it "creates owner 'rutger'" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_citysdk
      post "/owners", read_test_data('owner_rutger.json')
      status_should(last_response, 201)
      body_json(last_response)[:name].should == 'rutger'
    end

    it "creates owner '[tom] " do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_citysdk
      data = read_test_data_json 'owner_tom.json'
      data[:name] = '[tom]'
      post "/owners", data.to_json
      status_should(last_response, 422)
      body_json(last_response).should == {error: "'name' can only contain alphanumeric characters, underscores and periods"}
    end
  end

  describe "PATCH /owners" do
    it "edits owner 'bert' " do
      header "X-Auth", $key_bert
      header "CONTENT_TYPE", "application/json"
      fullname = 'Bert “😩” Spaan'
      patch "/owners/bert", {fullname: fullname}.to_json
      status_should(last_response, 200)
      body_json(last_response)[:fullname].should == fullname
    end

    it "edits owner 'bert', set role to admin " do
      header "X-Auth", $key_bert
      header "CONTENT_TYPE", "application/json"
      patch "/owners/bert", {admin: true}.to_json
      status_should(last_response, 401)
      body_json(last_response).should == {error: "Operation requires administrative authorization"}
    end

    it "edits owner 'tom' " do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_citysdk
      website = 'http://demeyer.nl/Lembeh-2014'
      patch "/owners/tom", {website: website}.to_json
      status_should(last_response, 200)
      body_json(last_response)[:website].should == website
    end

    it "edits name of owner 'tom''" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_citysdk
      data = read_test_data_json 'owner_tom.json'
      data[:name] = 'tommie'
      patch "/owners/tom", data.to_json
      status_should(last_response, 422)
      body_json(last_response).should == {error: "Owner name cannot be changed"}
    end

    it "gets all created owners and default owner 'citysdk'" do
      expected_owners = ['tom', 'bert', 'rutger', 'citysdk']
      get "/owners"
      status_should(last_response, 200)
      data = body_json(last_response)
      data.length.should == expected_owners.length
      (data.map { |owner| owner[:name] } - expected_owners).blank?.should == true
    end

    it "gets owner that doesn't exist" do
      get "/owners/tommie"
      status_should(last_response, 404)
    end

    # TODO: get single owner: turtle, json, etc.

  end

  ######################################################################
  # layers:
  ######################################################################

  describe "POST /layers" do
    it "bert creates layer without authorization" do
      header "CONTENT_TYPE", "application/json"
      data = read_test_data_json 'layer_bert.dierenwinkels.json'
      data.delete(:fields)
      data.delete(:context)
      post "/layers", data.to_json
      status_should(last_response, 401)
      body_json(last_response).should == { error: "Operation requires authorization"}
    end

    it "bert creates layer in wrong domain" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_bert
      data = read_test_data_json 'layer_bert.dierenwinkels.json'
      data.delete(:fields)
      data.delete(:context)
      data[:name] = 'pipo.dierenwinkels'
      post "/layers", data.to_json
      status_should(last_response, 403)
      body_json(last_response).should == {error: "Owner has no access to domain 'pipo'"}
    end

    it "creates layer 'bert.dierenwinkels'" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_bert
      data = read_test_data_json 'layer_bert.dierenwinkels.json'
      data.delete(:fields)
      data.delete(:context)
      post "/layers", data.to_json
      status_should(last_response, 201)
      body_json(last_response)[:features][0][:properties][:name].should == 'bert.dierenwinkels'
    end

    it "creates layer 'tom.achtbanen'" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_citysdk
      post "/layers", read_test_data('layer_tom.achtbanen.json')
      status_should(last_response, 201)
      body_json(last_response)[:features][0][:properties][:name].should == 'tom.achtbanen'
    end

    it "creates layer 'tom.steden'" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_citysdk
      post "/layers", read_test_data('layer_tom.steden.json')
      status_should(last_response, 201)
      body_json(last_response)[:features][0][:properties][:name].should == 'tom.steden'
    end

    it "creates virtual layer 'steden.inw'" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_citysdk
      post "/layers", read_test_data('layer_tom.virtual.json')
      status_should(last_response, 201)
      body_json(last_response)[:features][0][:properties][:name].should == 'steden.inw'
    end

    it "creates layer 'rutger.openingstijden'" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_citysdk
      post "/layers", read_test_data('layer_rutger.openingstijden.json')
      status_should(last_response, 201)
      body_json(last_response)[:features][0][:properties][:name].should == 'rutger.openingstijden'
    end
  end

  describe "PATCH /layers" do
    it "edits layer 'bert.dierenwinkels' without authorization" do
      header "CONTENT_TYPE", "application/json"
      title = 'Alle dierenwinkels in Nederland - 🐢🐭🐴'
      patch "/layers/bert.dierenwinkels", {title: title}.to_json
      status_should(last_response, 401)
      body_json(last_response).should == {error: "Operation requires correct authorization - must be resource's owner or admin"}
    end

    it "edits layer 'bert.dierenwinkels' " do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_bert
      title = 'Alle dierenwinkels in Nederland - 🐢🐭🐴'
      patch "/layers/bert.dierenwinkels", {title: title}.to_json
      status_should(last_response, 200)
      body_json(last_response)[:features][0][:properties][:title].should == title
    end

    it "set owner of 'bert.dierenwinkels' to 'rutger'" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_bert
      owner = 'rutger'
      patch "/layers/bert.dierenwinkels", {owner: owner}.to_json
      status_should(last_response, 200)
    end

    it "owner of 'bert.dierenwinkels' should not be rutger" do
      get '/layers/bert.dierenwinkels/owners'
      status_should(last_response, 200)
      body_json(last_response)[0][:name].should == 'bert'
    end

    it "sets owner of 'bert.dierenwinkels' to owner that does not exist" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_citysdk
      owner = 'jos'
      patch "/layers/bert.dierenwinkels", {owner: owner}.to_json
      status_should(last_response, 422)
      body_json(last_response).should == {error: "Owner does not exist: 'jos'"}
    end

    it "sets owner of layer 'bert.dierenwinkels' back to 'bert'" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_citysdk
      owner = 'bert'
      patch "/layers/bert.dierenwinkels", {owner: owner}.to_json
      status_should(last_response, 200)
    end

    it "gets all layers" do
      expected_layers = [
        'bert.dierenwinkels', 'rutger.openingstijden',
        'tom.achtbanen', 'tom.steden', 'steden.inw'
      ]
      get "/layers"
      status_should(last_response, 200)
      data = body_json(last_response)
      last_response.header["X-Result-Count"].to_i.should == 5
      data[:features].length.should == expected_layers.length
      (data[:features].map { |layer| layer[:properties][:name] } - expected_layers).blank?.should == true
    end

    it "gets layer that doesn't exist" do
      get "/layers/bert.achtbanen"
      status_should(last_response, 404)
    end
  end

  describe "context" do
    ######################################################################
    # context:
    ######################################################################


    it "gets JSON-LD context of layer 'tom.achtbanen'" do
      data = read_test_data_json 'layer_tom.achtbanen.json'
      get "/layers/tom.achtbanen/context"
      status_should(last_response, 200)
      body_json(last_response).should == data[:context]
    end

    it "gets JSON-LD context of layer 'bert.dierenwinkels'" do
      get "/layers/bert.dierenwinkels/context"
      status_should(last_response, 200)
      body_json(last_response).should == {}
    end

    it "sets JSON-LD context of layer 'bert.dierenwinkels'" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_bert
      data = read_test_data_json 'layer_bert.dierenwinkels.json'
      put "/layers/bert.dierenwinkels/context", data[:context].to_json
      status_should(last_response, 200)
      body_json(last_response).should == data[:context]
    end

    # TODO: this test still fails!
    # Serialization should only be attemped when content type matches possible output
    # describe "GET /layers/bert.dierenwinkels/context" do
    #   it "tries to get RDF/Turtle version of JSON-LD context" do
    #     get "/layers/bert.dierenwinkels/@context", nil, {'HTTP_ACCEPT' => "text/turtle"}
    #     status_should(last_response, 406)
    #   end
    # end

  end

  describe "fields" do
    ######################################################################
    # fields:
    ######################################################################

    it "gets fields of layer 'tom.achtbanen'" do
      data = read_test_data_json 'layer_tom.achtbanen.json'
      get "/layers/tom.achtbanen/fields"
      status_should(last_response, 200)
      body_json(last_response).length.should == data[:fields].length
    end

    it "creates multiple fields for layer 'bert.dierenwinkels'" do
      data = read_test_data_json 'layer_bert.dierenwinkels.json'
      data[:fields].each do |field|
        header "CONTENT_TYPE", "application/json"
        header "X-Auth", $key_bert
        post "/layers/bert.dierenwinkels/fields", field.to_json
        status_should(last_response, 201)
        compare_hash(body_json(last_response), field).should == true
      end
    end

    it "creates single field for layer 'bert.dierenwinkels'" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_bert
      field = {
        name: "field",
        description: "1, 2, 3, 4, 5!"
      }
      post "/layers/bert.dierenwinkels/fields", field.to_json
      status_should(last_response, 201)
      body_json(last_response).should == field
    end

    it "edits single field 'field' for layer 'bert.dierenwinkels'" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_bert
      field = {
        name: "field",
        description: "1, 2, 3, 4, 5!",
        lang: "nl"
      }
      patch "/layers/bert.dierenwinkels/fields/field", {lang: field[:lang]}.to_json
      status_should(last_response, 200)
      body_json(last_response).should == field
    end

    it "deletes single field 'field' for layer 'bert.dierenwinkels'" do
      header "X-Auth", $key_bert
      delete "/layers/bert.dierenwinkels/fields/field"
      status_should(last_response, 204)
      last_response.body.should == ''
    end

    it "gets fields of layer 'bert.dierenwinkels'" do
      data = read_test_data_json 'layer_bert.dierenwinkels.json'
      get "/layers/bert.dierenwinkels/fields"
      status_should(last_response, 200)
      body_json(last_response).length.should == data[:fields].length
    end

    it "gets 'lengte' field of layer 'tom.achtbanen'" do
      get "/layers/tom.achtbanen/fields/lengte"
      status_should(last_response, 200)
      # TODO serializations
    end
  end

  describe "POST/PATCH objects" do

    ######################################################################
    # objects + data:
    ######################################################################

    it "creates objects and data on layer 'bert.dierenwinkels'" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_bert
      data = read_test_data_json 'objects_bert.dierenwinkels.json'
      data = {
        type: "FeatureCollection",
        features: data[:features][0..-2]
      }
      post "/layers/bert.dierenwinkels/objects", data.to_json
      status_should(last_response, 201)
      body_json(last_response).length.should == data[:features].length
    end

    it "creates single object with data on layer 'bert.dierenwinkels'" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_bert
      data = read_test_data_json 'objects_bert.dierenwinkels.json'
      data = data[:features][-1]
      post "/layers/bert.dierenwinkels/objects", data.to_json
      status_should(last_response, 201)
      body_json(last_response).length.should == 1
    end

    it "creates single object with id containing '.'" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_bert
      data = {
        type: "Feature",
        properties: {
          id: "a.b",
          title: "Winkel met 'n Punt",
          data: {
            icon: "🚤",
          }
        },
        geometry: {
          type: "Point",
          coordinates: [4.28741, 52.07106]
        }
      }
      post "/layers/bert.dierenwinkels/objects", data.to_json
      status_should(last_response, 201)
      get "objects/bert.dierenwinkels.a.b"
      body_json(last_response)[:features].length.should == 1
    end

    it "edits data of single object" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_bert
      data = {
        type: "Feature",
        properties: {
          data: {
            icon: "🙍",
          }
        }
      }
      patch "/objects/bert.dierenwinkels.a.b", data.to_json
      status_should(last_response, 200)
      body_json(last_response)[0].should == {cdk_id: 'bert.dierenwinkels.a.b'}
      get "objects/bert.dierenwinkels.a.b"
      body_json(last_response)[:features][0][:properties][:layers][:"bert.dierenwinkels"][:data][:icon].should == "🙍"
    end

    it "edits title of single object" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_bert
      data = {
        type: "Feature",
        properties: {
          title: "Winkel met een punt"
        }
      }
      patch "/objects/bert.dierenwinkels.a.b", data.to_json
      status_should(last_response, 200)
      get "objects/bert.dierenwinkels.a.b"
      body_json(last_response)[:features][0][:properties][:title].should == "Winkel met een punt"
    end

    it "edits geometry of single object" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_bert
      data = {
        type: "Feature",
        geometry: {
          type: "Point",
          coordinates: [4.040404, 52.00025]
        }
      }
      patch "/objects/bert.dierenwinkels.a.b", data.to_json
      status_should(last_response, 200)
      get "objects/bert.dierenwinkels.a.b"
      body_json(last_response)[:features][0][:geometry][:coordinates] == [4.040404, 52.00025]
    end

    it "edits geometry, title and data of single object" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_bert
      data = {
        type: "Feature",
        properties: {
          title: "Winkel met de Punt",
          data: {
            icon: "🚚",
          }
        },
        geometry: {
          type: "Point",
          coordinates: [4.444444, 52.525252]
        }
      }
      patch "/objects/bert.dierenwinkels.a.b", data.to_json
      status_should(last_response, 200)
      get "objects/bert.dierenwinkels.a.b"
      feature = body_json(last_response)[:features][0]
      feature[:properties][:title].should == "Winkel met de Punt"
      feature[:properties][:layers][:'bert.dierenwinkels'][:data][:icon].should == "🚚"
      feature[:geometry][:coordinates].should == [4.444444, 52.525252]
    end

    it "creates single object without geometry" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_bert
      data = read_test_data_json 'objects_bert.dierenwinkels.json'
      data = data[:features][-1]
      data.delete(:geometry)
      post "/layers/bert.dierenwinkels/objects", data.to_json
      status_should(last_response, 422)
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
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_bert
      post "/layers/bert.dierenwinkels/objects", data.to_json
      body_json(last_response).should == {error: "GeoJSON GeometryCollections are not allowed as object geometry"}
    end

    it "creates single object with invalid GeoJSON geometry" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_bert
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
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_bert
      data = read_test_data_json 'objects_bert.dierenwinkels.json'
      data = data[:features][-1]
      data[:geometry] = {
        type: "Point",
        coordinates: [5.16521, 52.22154, -1]
      }
      post "/layers/bert.dierenwinkels/objects", data.to_json
      body_json(last_response).should == {error: "Geometry has Z dimension but column does not"}
    end

    it "creates single object with duplicate id" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_bert
      data = read_test_data_json 'objects_bert.dierenwinkels.json'
      data = data[:features][-1]
      post "/layers/bert.dierenwinkels/objects", data.to_json
      status_should(last_response, 422)
      body_json(last_response).should == {error: "cdk_id must be unique: 'bert.dierenwinkels.3'"}
    end

    it "creates single object without id" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_bert
      data = read_test_data_json 'objects_bert.dierenwinkels.json'
      data = data[:features][-1]
      data[:properties].delete(:id)
      post "/layers/bert.dierenwinkels/objects", data.to_json
      status_should(last_response, 422)
      body_json(last_response).should == {error: "All objects must either have 'id' or 'cdk_id' property"}
    end

    it "adds data to cdk_id that doesn't exist" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_bert
      data = read_test_data_json 'objects_bert.dierenwinkels.json'
      data = data[:features][-1]
      data.delete(:geometry)
      data[:properties].delete(:title)
      data[:properties].delete(:id)
      data[:properties][:cdk_id] = '12345'
      post "/layers/bert.dierenwinkels/objects", data.to_json
      status_should(last_response, 422)
      body_json(last_response).should == {error: "Object not found: '#{data[:properties][:cdk_id]}'"}
    end

    it "creates single object without data" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_bert
      data = read_test_data_json 'objects_bert.dierenwinkels.json'
      data = data[:features][-1]
      data[:properties].delete(:data)
      post "/layers/bert.dierenwinkels/objects", data.to_json
      status_should(last_response, 422)
      body_json(last_response).should == {error: "Object without data encountered"}
    end

    it "creates objects and data on layer that doesn't exist" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_bert
      post "/layers/bert.bioscopen/objects", read_test_data('objects_bert.dierenwinkels.json')
      status_should(last_response, 404)
      body_json(last_response).should == {error: "Layer not found: 'bert.bioscopen'"}
    end

    it "creates objects and data on layer 'tom.achtbanen'" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_citysdk
      data = read_test_data_json 'objects_tom.achtbanen.json'
      post "/layers/tom.achtbanen/objects", data.to_json
      status_should(last_response, 201)
      body_json(last_response).length.should == data[:features].length
    end

    it "creates objects and data on layer 'tom.steden'" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_citysdk
      data = read_test_data_json 'objects_tom.steden.json'
      post "/layers/tom.steden/objects", data.to_json
      status_should(last_response, 201)
      body_json(last_response).length.should == data[:features].length
    end

    it "edits data on layer 'tom.steden' of tom.steden.utrecht" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_citysdk
      patch "/objects/tom.steden.utrecht/layers/tom.steden", {inwoners: 542322}.to_json
      status_should(last_response, 200)
      get "/objects/tom.steden.utrecht"
      body_json(last_response)[:features][0][:properties][:layers][:'tom.steden'][:data][:inwoners].should == "542322"
    end

    it "adds data on layer 'rutger.openingstijden' to existing objects" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_citysdk
      data = read_test_data_json 'objects_rutger.openingstijden.json'
      post "/layers/rutger.openingstijden/objects", data.to_json
      status_should(last_response, 201)
      body_json(last_response).length.should == data[:features].length
    end

    it "adds duplicate data on layer 'rutger.openingstijden' to existing objects" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_citysdk
      data = read_test_data_json 'objects_rutger.openingstijden.json'
      post "/layers/rutger.openingstijden/objects", data.to_json
      status_should(last_response, 422)
      body_json(last_response).should == {error: "Object already has data on this layer"}
    end

    # TODO:
    #   - add test to make sure adding data to existing object (with cdk_id) while also
    #     specifying geometry/title is not allowed
    #   - edit multiple object's geometry/title (should this even be possible?)
    #   - check JSON-LD and Turtle serializations of multiple objects
    #   - check object-on-layer meta-data: /layers/rutger.openingstijden/objects/bert.dierenwinkels.1
  end

  describe "GET filters" do
    ######################################################################
    # filters:
    ######################################################################

    # All filters:
    # [cdk_id, layer, owner, field, in, contains, bbox, nearby, title, data]

    it "gets 10 objects closest to location" do
      get "/objects?lat=52.37277&lon=4.90033"
      status_should(last_response, 200)
      body_json(last_response)[:features][0][:properties][:cdk_id].should == 'tom.achtbanen.2'
      body_json(last_response)[:features][1][:properties][:cdk_id].should == 'bert.dierenwinkels.1'
    end

    it "gets objects within 1692 m. of location" do
      get "/layers/bert.dierenwinkels/objects?lat=52.37277&lon=4.90033&radius=1692"
      status_should(last_response, 200)
      last_response.header["X-Result-Count"].to_i.should == 1
      # Executing
      #   SELECT ST_Distance(Geography(ST_SetSRID(ST_MakePoint(4.90033, 52.37277), 4326)),
      #   Geography(ST_SetSRID(ST_MakePoint(4.8793, 52.36469), 4326)))
      # returns: 1691.197905984
    end

    it "gets objects on layer 'tom.achtbanen' contained by 'tom.steden.utrecht'" do
      get "/layers/tom.achtbanen/objects?in=tom.steden.utrecht"
      status_should(last_response, 200)
      last_response.header["X-Result-Count"].to_i.should == 2
      body_json(last_response)[:features].map {|f|
        f[:properties][:cdk_id]
      }.sort.should == ['tom.achtbanen.4', 'tom.achtbanen.5']
    end

    it "gets objects on layer 'tom.steden' containing 'tom.achtbanen.4'" do
      get "/layers/tom.steden/objects?contains=tom.achtbanen.4"
      status_should(last_response, 200)
      last_response.header["X-Result-Count"].to_i.should == 1
      body_json(last_response)[:features][0][:properties][:cdk_id].should == 'tom.steden.utrecht'
    end

    it "gets one page of objects and object count" do
      get "/objects?title=spinnen"
      status_should(last_response, 200)
      last_response.header["X-Result-Count"].to_i.should == 1
      body_json(last_response)[:features][0][:properties][:title].should ==
          'Het Grote Spinnen- en insectenimperium'
    end

    it "gets objects within bounding box" do
      get "/objects?bbox=52.38901,4.79519,52.35191,5.01135"
      status_should(last_response, 200)
      last_response.header["X-Result-Count"].to_i.should == 2
      body_json(last_response)[:features][0][:properties][:cdk_id].should == 'bert.dierenwinkels.1'
      body_json(last_response)[:features][1][:properties][:cdk_id].should == 'tom.achtbanen.2'
    end
    it "gets one object with icon = 🐟" do
      get URI::encode("/objects?bert.dierenwinkels::icon=🐟")
      status_should(last_response, 200)
      last_response.header["X-Result-Count"].to_i.should == 1
      icon = body_json(last_response)[:features][0][:properties][:layers][:'bert.dierenwinkels'][:data][:icon]
      icon.should == '🐟'
    end
  end

  # layer

  # TODO: create tests for:
  #   http://localhost:9292/objects?layer=tom.steden
  #   http://localhost:9292/layers/rutger.openingstijden/objects?layer=*
  #   http://localhost:9292/objects/bert.dierenwinkels.1?layer=*
  #   http://localhost:9292/objects?rutger.openingstijden::tot=🕕&layer=*
  #   http://localhost:9292/objects?bert.dierenwinkels::type&layer=rutger.openingstijden
  #   http://localhost:9292/objects?rutger.openingstijden::tot=🕕&tom.achtbanen::lengte=241
  #   http://localhost:9292/objects?layer=rutger.openingstijden,bert.dierenwinkels

  describe "Accept header & pagination" do
    ######################################################################
    # Accept header:
    ######################################################################

    # it "uses Accept header to get RDF/Turtle of /objects" do
    #   get "/objects", nil, {'HTTP_ACCEPT' => "text/turtle"}
    #   status_should(last_response, 200)
    #   last_response.header['Content-Type'].should == 'text/turtle'
    # end

    it "uses Accept header to get JSON-LD of /objects" do
      get "/objects", nil, {'HTTP_ACCEPT' => "application/ld+json"}
      status_should(last_response, 200)
      last_response.header['Content-Type'].should == 'application/json'
      body_json(last_response).has_key?(:@context).should == true
    end

    it "checks if pagination Link headers are set for query on multiple layers" do
      get "/objects?layer=rutger.openingstijden,bert.dierenwinkels&per_page=3&page=2"
      status_should(last_response, 200)
      last_response.header["X-Result-Count"].to_i.should == 3
      last_response.header["Link"].should == [
        '<http://example.org/objects?layer=rutger.openingstijden,bert.dierenwinkels&page=1&per_page=3>; rel="first"',
        '<http://example.org/objects?layer=rutger.openingstijden,bert.dierenwinkels&page=1&per_page=3>; rel="prev"',
        '<http://example.org/objects?layer=rutger.openingstijden,bert.dierenwinkels&page=2&per_page=3>; rel="last"'
      ].join(', ')
    end

  end

  describe "miscellaneous" do
    ######################################################################
    # miscellaneous:
    ######################################################################

    it "gets endpoint status" do
      get "/"
      status_should(last_response, 200)
      # TODO: check endpoint content
    end

    it "gets all admin owners" do
      get "/owners?admin=true"
      status_should(last_response, 200)
      last_response.header["X-Result-Count"].to_i.should == 2
    end

    it "gets all non-admin owners" do
      get "/owners?admin=false"
      status_should(last_response, 200)
      last_response.header["X-Result-Count"].to_i.should == 2
    end

    it "gets all authoritative layers" do
      get "/layers?authoritative=true"
      status_should(last_response, 200)
      last_response.header["X-Result-Count"].to_i.should == 1
    end

    it "gets all non-authoritative layers" do
      get "/layers?authoritative=false"
      status_should(last_response, 200)
      last_response.header["X-Result-Count"].to_i.should == 4
    end

    object_count = 0
    it "gets all objects and object count" do
      get "/objects?count&per_page=250"
      status_should(last_response, 200)
      object_count = body_json(last_response)[:features].length
      last_response.header["X-Result-Count"].to_i.should == object_count

      # Apparently, rspec sets hostname to 'example.org'
      last_response.header["Link"].should ==
          '<http://example.org/objects?count&page=1&per_page=250>; rel="last"'
    end

    it "gets one page of objects and object count" do
      get "/objects?count"
      status_should(last_response, 200)
      last_response.header["X-Result-Count"].to_i.should == object_count
      last_response.header["Link"].should == [
        '<http://example.org/objects?count&page=3&per_page=10>; rel="last"',
        '<http://example.org/objects?count&page=2&per_page=10>; rel="next"'
      ].join(', ')
    end

    it "gets owners of layer 'tom.achtbanen'" do
      get "/layers/tom.achtbanen/owners"
      status_should(last_response, 200)
      body_json(last_response).length.should == 1
      body_json(last_response)[0][:name].should == 'tom'
    end

    it "gets layers of owner 'tom'" do
      get "/owners/tom/layers"
      status_should(last_response, 200)
      body_json(last_response)[:features].length.should == 2
    end

    it "gets bounding boxes of all layers" do
      get "/layers"
      status_should(last_response, 200)
      all_polygons = body_json(last_response)[:features].map {|f| f[:geometry][:type] == 'Polygon' }.inject(:&)
      all_polygons.should == true
    end

    it "calls DELETE /layers and checks if response is 405 Method Now Allowed" do
      delete "/layers"
      status_should(last_response, 405)
    end
  end

  describe "DELETE" do

    it "deletes single object 'bert.dierenwinkels.1'" do
      header "X-Auth", $key_bert
      delete "/objects/bert.dierenwinkels.1"
      status_should(last_response, 204)
      last_response.body.should == ''
    end

    it "checks if 'bert.dierenwinkels.1' is moved to layer 'none' and still has data on 'rutger.openingstijden" do
      get "/objects/bert.dierenwinkels.1"
      status_should(last_response, 200)
      body_json(last_response)[:features][0][:properties][:layer].should == ':layers/none'
      tot = body_json(last_response)[:features][0][:properties][:layers][:'rutger.openingstijden'][:data][:tot]
      tot.should == '🕙'
    end

    it "deletes data on layer 'rutger.openingstijden' on single object 'bert.dierenwinkels.1'" do
      header "X-Auth", $key_citysdk
      delete "/objects/bert.dierenwinkels.1/layers/rutger.openingstijden"
      status_should(last_response, 204)
      last_response.body.should == ''
    end

    it "checks if object 'bert.dierenwinkels.1' is deleted" do
      get "/objects/bert.dierenwinkels.1"
      status_should(last_response, 404)
      body_json(last_response).should == {error: "Object not found: 'bert.dierenwinkels.1'"}
    end

    it "deletes layer 'bert.dierenwinkels'" do
      header "X-Auth", $key_citysdk
      delete "/layers/bert.dierenwinkels"
      status_should(last_response, 204)
      last_response.body.should == ''
    end

    it "checks if all objects with data on 'rutger.openingstijden' are on layer 'none' and 'tom.achtbanen'" do
      get "/layers/rutger.openingstijden/objects"
      status_should(last_response, 200)
      last_response.header["X-Result-Count"].to_i.should == 5
      body_json(last_response)[:features].map {|f| f[:properties][:layer] }.sort.should ==
        [':layers/none', ':layers/none', ':layers/tom.achtbanen', ':layers/tom.achtbanen', ':layers/tom.achtbanen']
    end

    it "deletes owner 'rutger'" do
      header "X-Auth", $key_citysdk
      delete "/owners/rutger"
      status_should(last_response, 204)
      last_response.body.should == ''
    end

    it "checks if orphaned objects are correctly deleted" do
      delete "/objects/bert.dierenwinkels.3"
      status_should(last_response, 404)
      body_json(last_response).should == {error: "Object not found: 'bert.dierenwinkels.3'"}
    end

    it "deletes owner 'bert'" do
      header "X-Auth", $key_citysdk
      delete "/owners/bert"
      status_should(last_response, 204)
      last_response.body.should == ''
    end

    it "deletes owner 'tom'" do
      header "X-Auth", $key_citysdk
      delete "/owners/tom"
      status_should(last_response, 204)
      last_response.body.should == ''
    end

    it "checks whether all objects are deleted" do
      get "/objects"
      status_should(last_response, 200)
      last_response.header["X-Result-Count"].to_i.should == 0
      body_json(last_response)[:features].length.should == 0
    end

  end

end