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
        last_response.status.should == 200
        $citysdk_key = body_json(last_response)[:features][0][:properties][:session_key]
        $citysdk_key.should_not == nil
      end
    end
    
    describe "POST /owners" do
      
      it "creates owner 'bert' without authorization" do
        header "CONTENT_TYPE", "application/json"
        post "/owners", read_test_data('owner_bert.json')
        last_response.status.should == 401
        body_json(last_response).should == {error: "Operation requires administrative authorization"}
      end


      it "creates owner 'bert'" do
        header "CONTENT_TYPE", "application/json"
        header "X-Auth", $citysdk_key
        post "/owners", read_test_data('owner_bert.json')
        last_response.status.should == 201
        body_json(last_response)[:name].should == 'bert'
      end

      it "gets a session key for owner 'bert'" do
        header "CONTENT_TYPE", "application/json"
        get "/session?name=bert&password=abcABC123"
        last_response.status.should == 200
        $bert_key = body_json(last_response)[:features][0][:properties][:session_key]
        $bert_key.should_not == nil
      end

      it "creates another owner 'bert' " do
        header "CONTENT_TYPE", "application/json"
        header "X-Auth", $citysdk_key
        post "/owners", read_test_data('owner_bert.json')
        last_response.status.should == 422
        body_json(last_response).should == {error: "Owner already exists: bert"}
      end

      it "creates owner 'tom' with a too simple password" do
        header "CONTENT_TYPE", "application/json"
        header "X-Auth", $citysdk_key
        post "/owners", read_test_data('owner_tom.json').gsub('ABCabc456', 'nix')
        last_response.status.should == 422
        body_json(last_response).should == {error: 'Password needs to be longer, or contain numbers, capitals or symbols'}
      end

      it "creates owner 'tom'" do
        header "CONTENT_TYPE", "application/json"
        header "X-Auth", $citysdk_key
        post "/owners", read_test_data('owner_tom.json')
        last_response.status.should == 201
        body_json(last_response)[:name].should == 'tom'
      end

      it "creates owner 'tom' without admin authorization" do
        header "CONTENT_TYPE", "application/json"
        header "X-Auth", $bert_key
        post "/owners", read_test_data('owner_tom.json')
        last_response.status.should == 401
        body_json(last_response).should == {error: "Operation requires administrative authorization"}
      end

      it "creates owner 'rutger'" do
        header "CONTENT_TYPE", "application/json"
        header "X-Auth", $citysdk_key
        post "/owners", read_test_data('owner_rutger.json')
        last_response.status.should == 201
        body_json(last_response)[:name].should == 'rutger'
      end

      it "creates owner '[tom] " do
        data = read_test_data_json 'owner_tom.json'
        data[:name] = '[tom]'
        header "CONTENT_TYPE", "application/json"
        header "X-Auth", $citysdk_key
        post "/owners", data.to_json
        last_response.status.should == 422
        body_json(last_response).should == {error: "'name' can only contain alphanumeric characters, underscores and periods"}
      end
    end

    describe "PATCH /owners" do
      it "edits owner 'bert' " do
        fullname = 'Bert “😩” Spaan'
        header "X-Auth", $bert_key
        header "CONTENT_TYPE", "application/json"
        patch "/owners/bert", {fullname: fullname}.to_json
        last_response.status.should == 200
        body_json(last_response)[:fullname].should == fullname
      end

      it "edits owner 'bert', set role to admin " do
        header "X-Auth", $bert_key
        header "CONTENT_TYPE", "application/json"
        patch "/owners/bert", {admin: true}.to_json
        last_response.status.should == 401
        body_json(last_response).should == {error: "Operation requires administrative authorization"}
      end

      it "edits owner 'tom' " do
        website = 'http://demeyer.nl/Lembeh-2014'
        header "CONTENT_TYPE", "application/json"
        header "X-Auth", $citysdk_key
        patch "/owners/tom", {website: website}.to_json
        last_response.status.should == 200
        body_json(last_response)[:website].should == website
      end

      it "edits name of owner 'tom''" do
        data = read_test_data_json 'owner_tom.json'
        data[:name] = 'tommie'
        header "CONTENT_TYPE", "application/json"
        header "X-Auth", $citysdk_key
        patch "/owners/tom", data.to_json
        last_response.status.should == 422
        body_json(last_response).should == {error: "Owner name cannot be changed"}
      end

      it "gets all created owners and default owner 'citysdk'" do
        expected_owners = ['tom', 'bert', 'rutger', 'citysdk']
        get "/owners"
        last_response.status.should == 200
        data = body_json(last_response)
        data.length.should == expected_owners.length
        (data.map { |owner| owner[:name] } - expected_owners).blank?.should == true
      end

      it "gets owner that doesn't exist" do
        get "/owners/tommie"
        last_response.status.should == 404
      end

      # TODO: get single owner: turtle, json, etc.

    end


    ######################################################################
    # layers:
    ######################################################################

    describe "POST /layers" do
      it "bert creates layer without authorization" do
        data = read_test_data_json 'layer_bert.dierenwinkels.json'
        data.delete(:fields)
        data.delete(:@context)
        header "CONTENT_TYPE", "application/json"
        post "/layers", data.to_json
        last_response.status.should == 401
        body_json(last_response).should == { error: "Operation requires authorization"}
      end

      it "bert creates layer in wrong domain" do
        data = read_test_data_json 'layer_bert.dierenwinkels.json'
        data.delete(:fields)
        data.delete(:@context)
        data[:name] = 'pipo.dierenwinkels'
        header "CONTENT_TYPE", "application/json"
        header "X-Auth", $bert_key
        post "/layers", data.to_json
        last_response.status.should == 403
        body_json(last_response).should == { error: "Owner has no access to domain 'pipo'" }
      end

      it "creates layer 'bert.dierenwinkels'" do
        data = read_test_data_json 'layer_bert.dierenwinkels.json'
        data.delete(:fields)
        data.delete(:@context)
        header "CONTENT_TYPE", "application/json"
        header "X-Auth", $bert_key
        post "/layers", data.to_json
        last_response.status.should == 201
        body_json(last_response)[:features][0][:properties][:name].should == 'bert.dierenwinkels'
      end

      it "creates layer 'tom.achtbanen'" do
        header "CONTENT_TYPE", "application/json"
        header "X-Auth", $citysdk_key
        post "/layers", read_test_data('layer_tom.achtbanen.json')
        last_response.status.should == 201
        body_json(last_response)[:features][0][:properties][:name].should == 'tom.achtbanen'
      end

      it "creates layer 'tom.steden'" do
        header "CONTENT_TYPE", "application/json"
        header "X-Auth", $citysdk_key
        post "/layers", read_test_data('layer_tom.steden.json')
        last_response.status.should == 201
        body_json(last_response)[:features][0][:properties][:name].should == 'tom.steden'
      end

      it "creates layer 'rutger.openingstijden'" do
        header "CONTENT_TYPE", "application/json"
        header "X-Auth", $citysdk_key
        post "/layers", read_test_data('layer_rutger.openingstijden.json')
        last_response.status.should == 201
        body_json(last_response)[:features][0][:properties][:name].should == 'rutger.openingstijden'
      end
    end

    describe "PATCH /layers" do
      it "edits layer 'bert.dierenwinkels' without authorization" do
        title = 'Alle dierenwinkels in Nederland - 🐢🐭🐴'
        header "CONTENT_TYPE", "application/json"
        patch "/layers/bert.dierenwinkels", {title: title}.to_json
        last_response.status.should == 401
        body_json(last_response).should == { error: "Operation requires owners' authorization" }
      end

      it "edits layer 'bert.dierenwinkels' " do
        title = 'Alle dierenwinkels in Nederland - 🐢🐭🐴'
        header "CONTENT_TYPE", "application/json"
        header "X-Auth", $bert_key
        patch "/layers/bert.dierenwinkels", {title: title}.to_json
        last_response.status.should == 200
        body_json(last_response)[:features][0][:properties][:title].should == title
      end

      it "set owner of 'bert.dierenwinkels' to 'rutger'" do
        owner = 'rutger'
        header "CONTENT_TYPE", "application/json"
        header "X-Auth", $bert_key
        patch "/layers/bert.dierenwinkels", {owner: owner}.to_json
        last_response.status.should == 200
      end

      it "owner of 'bert.dierenwinkels' should not be rutger" do
        get '/layers/bert.dierenwinkels/owners'
        last_response.status.should == 200
        body_json(last_response)[0][:name].should == 'bert'
      end

      it "sets owner of 'bert.dierenwinkels' to owner that does not exist" do
        owner = 'jos'
        header "CONTENT_TYPE", "application/json"
        header "X-Auth", $citysdk_key
        patch "/layers/bert.dierenwinkels", {owner: owner}.to_json
        last_response.status.should == 422
        body_json(last_response).should == {error: "Owner does not exist: 'jos'"}
      end

      it "sets owner of layer 'bert.dierenwinkels' back to 'bert'" do
        owner = 'bert'
        header "CONTENT_TYPE", "application/json"
        header "X-Auth", $citysdk_key
        patch "/layers/bert.dierenwinkels", {owner: owner}.to_json
        last_response.status.should == 200
      end

      it "gets all layers" do
        expected_layers = [
          'bert.dierenwinkels', 'rutger.openingstijden',
          'tom.achtbanen', 'tom.steden'
        ]
        get "/layers"
        last_response.status.should == 200
        data = body_json(last_response)
        last_response.header["X-Result-Count"].to_i.should == 4
        data[:features].length.should == expected_layers.length
        (data[:features].map { |layer| layer[:properties][:name] } - expected_layers).blank?.should == true
      end

      it "gets layer that doesn't exist" do
        get "/layers/bert.achtbanen"
        last_response.status.should == 404
      end
    end


    describe "@context" do
      ######################################################################
      # context:
      ######################################################################


      it "gets JSON-LD context of layer 'tom.achtbanen'" do
        data = read_test_data_json 'layer_tom.achtbanen.json'
        get "/layers/tom.achtbanen/@context"
        last_response.status.should == 200
        body_json(last_response).should == data[:@context]
      end

      it "gets JSON-LD context of layer 'bert.dierenwinkels'" do
        get "/layers/bert.dierenwinkels/@context"
        last_response.status.should == 200
        body_json(last_response).should == {}
      end

      it "sets JSON-LD context of layer 'bert.dierenwinkels'" do
        data = read_test_data_json 'layer_bert.dierenwinkels.json'
        header "CONTENT_TYPE", "application/json"
        header "X-Auth", $bert_key
        put "/layers/bert.dierenwinkels/@context", data[:@context].to_json
        last_response.status.should == 200
        body_json(last_response).should == data[:@context]
      end

      # TODO: this test still fails!
      # Serialization should only be attemped when content type matches possible output
      # describe "GET /layers/bert.dierenwinkels/@context" do
      #   it "tries to get RDF/Turtle version of JSON-LD context" do
      #     get "/layers/bert.dierenwinkels/@context", nil, {'HTTP_ACCEPT' => "text/turtle"}
      #     puts last_response
      #     last_response.status.should == 406
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
        last_response.status.should == 200
        body_json(last_response).length.should == data[:fields].length
      end

      it "creates multiple fields for layer 'bert.dierenwinkels'" do
        data = read_test_data_json 'layer_bert.dierenwinkels.json'
        data[:fields].each do |field|
          header "CONTENT_TYPE", "application/json"
          header "X-Auth", $bert_key
          post "/layers/bert.dierenwinkels/fields", field.to_json
          last_response.status.should == 201
          compare_hash(body_json(last_response), field).should == true
        end
      end

      it "creates single field for layer 'bert.dierenwinkels'" do
        field = {
          name: "field",
          description: "1, 2, 3, 4, 5!"
        }
        header "CONTENT_TYPE", "application/json"
        header "X-Auth", $bert_key
        post "/layers/bert.dierenwinkels/fields", field.to_json
        last_response.status.should == 201
        body_json(last_response).should == field
      end

      it "edits single field 'field' for layer 'bert.dierenwinkels'" do
        field = {
          name: "field",
          description: "1, 2, 3, 4, 5!",
          lang: "nl"
        }
        header "CONTENT_TYPE", "application/json"
        header "X-Auth", $bert_key
        patch "/layers/bert.dierenwinkels/fields/field", {lang: field[:lang]}.to_json
        last_response.status.should == 200
        body_json(last_response).should == field
      end

      it "deletes single field 'field' for layer 'bert.dierenwinkels'" do
        header "X-Auth", $bert_key
        delete "/layers/bert.dierenwinkels/fields/field"
        last_response.status.should == 204
        last_response.body.should == ''
      end

      it "gets fields of layer 'bert.dierenwinkels'" do
        data = read_test_data_json 'layer_bert.dierenwinkels.json'
        get "/layers/bert.dierenwinkels/fields"
        last_response.status.should == 200
        body_json(last_response).length.should == data[:fields].length
      end

      it "gets 'lengte' field of layer 'tom.achtbanen'" do
        get "/layers/tom.achtbanen/fields/lengte"
        last_response.status.should == 200
        # TODO serializations
      end
    end

    describe "POST objects" do
      
      ######################################################################
      # objects + data:
      ######################################################################

      it "creates objects and data on layer 'bert.dierenwinkels'" do
        data = read_test_data_json 'objects_bert.dierenwinkels.json'
        data = {
          type: "FeatureCollection",
          features: data[:features][0..-2]
        }
        header "CONTENT_TYPE", "application/json"
        header "X-Auth", $bert_key
        post "/layers/bert.dierenwinkels/objects", data.to_json
        last_response.status.should == 201
        body_json(last_response).length.should == data[:features].length
      end

      it "creates single object with data on layer 'bert.dierenwinkels'" do
        data = read_test_data_json 'objects_bert.dierenwinkels.json'
        data = data[:features][-1]
        header "CONTENT_TYPE", "application/json"
        header "X-Auth", $bert_key
        post "/layers/bert.dierenwinkels/objects", data.to_json
        last_response.status.should == 201
        body_json(last_response).length.should == 1
      end

      it "creates single object without geometry" do
        data = read_test_data_json 'objects_bert.dierenwinkels.json'
        data = data[:features][-1]
        data.delete(:geometry)
        header "CONTENT_TYPE", "application/json"
        header "X-Auth", $bert_key
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
        header "CONTENT_TYPE", "application/json"
        header "X-Auth", $bert_key
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
        header "CONTENT_TYPE", "application/json"
        header "X-Auth", $bert_key
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
        header "CONTENT_TYPE", "application/json"
        header "X-Auth", $bert_key
        post "/layers/bert.dierenwinkels/objects", data.to_json
        body_json(last_response).should == {error: "Geometry has Z dimension but column does not"}
      end

      it "creates single object with duplicate id" do
        data = read_test_data_json 'objects_bert.dierenwinkels.json'
        data = data[:features][-1]
        header "CONTENT_TYPE", "application/json"
        header "X-Auth", $bert_key
        post "/layers/bert.dierenwinkels/objects", data.to_json
        last_response.status.should == 422
        body_json(last_response).should == {error: "cdk_id must be unique: 'bert.dierenwinkels.3'"}
      end

      it "creates single object without id" do
        data = read_test_data_json 'objects_bert.dierenwinkels.json'
        data = data[:features][-1]
        data[:properties].delete(:id)
        header "CONTENT_TYPE", "application/json"
        header "X-Auth", $bert_key
        post "/layers/bert.dierenwinkels/objects", data.to_json
        last_response.status.should == 422
        body_json(last_response).should == {error: "All objects must either have 'id' or 'cdk_id' property"}
      end

      it "adds data to cdk_id that doesn't exist" do
        data = read_test_data_json 'objects_bert.dierenwinkels.json'
        data = data[:features][-1]
        data.delete(:geometry)
        data[:properties].delete(:title)
        data[:properties].delete(:id)
        data[:properties][:cdk_id] = '12345'
        header "CONTENT_TYPE", "application/json"
        header "X-Auth", $bert_key
        post "/layers/bert.dierenwinkels/objects", data.to_json
        last_response.status.should == 422
        body_json(last_response).should == {error: "Object not found: '#{data[:properties][:cdk_id]}'"}
      end

      it "creates single object without data" do
        data = read_test_data_json 'objects_bert.dierenwinkels.json'
        data = data[:features][-1]
        data[:properties].delete(:data)
        header "CONTENT_TYPE", "application/json"
        header "X-Auth", $bert_key
        post "/layers/bert.dierenwinkels/objects", data.to_json
        last_response.status.should == 422
        body_json(last_response).should == {error: "Object without data encountered"}
      end


      it "creates objects and data on layer that doesn't exist" do
        header "CONTENT_TYPE", "application/json"
        header "X-Auth", $bert_key
        post "/layers/bert.bioscopen/objects", read_test_data('objects_bert.dierenwinkels.json')
        last_response.status.should == 404
        body_json(last_response).should == {error: "Layer not found: 'bert.bioscopen'"}
      end

      it "creates objects and data on layer 'tom.achtbanen'" do
        data = read_test_data_json 'objects_tom.achtbanen.json'
        header "CONTENT_TYPE", "application/json"
        header "X-Auth", $citysdk_key
        post "/layers/tom.achtbanen/objects", data.to_json
        last_response.status.should == 201
        body_json(last_response).length.should == data[:features].length
      end

      it "creates objects and data on layer 'tom.steden'" do
        data = read_test_data_json 'objects_tom.steden.json'
        header "CONTENT_TYPE", "application/json"
        header "X-Auth", $citysdk_key
        post "/layers/tom.steden/objects", data.to_json
        last_response.status.should == 201
        body_json(last_response).length.should == data[:features].length
      end

      it "adds data on layer 'rutger.openingstijden' to existing objects" do
        data = read_test_data_json 'objects_rutger.openingstijden.json'
        header "CONTENT_TYPE", "application/json"
        header "X-Auth", $citysdk_key
        post "/layers/rutger.openingstijden/objects", data.to_json
        last_response.status.should == 201
        body_json(last_response).length.should == data[:features].length
      end

      it "adds duplicate data on layer 'rutger.openingstijden' to existing objects" do
        data = read_test_data_json 'objects_rutger.openingstijden.json'
        header "CONTENT_TYPE", "application/json"
        header "X-Auth", $citysdk_key
        post "/layers/rutger.openingstijden/objects", data.to_json
        last_response.status.should == 422
        body_json(last_response).should == {error: "Object already has data on this layer"}
      end

      # TODO: add test to make sure adding data to existing object (with cdk_id) while also
      # specifying geometry/title is not allowed

      # TODO: add tests:
      #   - edit data of single object
      #       curl --data "{\"url\": \"http://vis.com/hond\"}" http://localhost:9292/objects/n46127914/layers/artsholland
      #       curl -X PUT --data "{\"chips\": \"nee\"}" http://localhost:9292/objects/n46127914/layers/artsholland
      #       curl --request PATCH --data "{\"url\": \"http://bertspaan.nl/\"}" http://localhost:9292/objects/n46127914/layers/artsholland
      #   - edit single object's geometry/title
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
        last_response.status.should == 200
        body_json(last_response)[:features][0][:properties][:cdk_id].should == 'tom.achtbanen.2'
        body_json(last_response)[:features][1][:properties][:cdk_id].should == 'bert.dierenwinkels.1'
      end

      it "gets objects within 1692 m. of location" do
        get "/layers/bert.dierenwinkels/objects?lat=52.37277&lon=4.90033&radius=1692"
        last_response.status.should == 200
        last_response.header["X-Result-Count"].to_i.should == 1
        # Executing
        #   SELECT ST_Distance(Geography(ST_SetSRID(ST_MakePoint(4.90033, 52.37277), 4326)),
        #   Geography(ST_SetSRID(ST_MakePoint(4.8793, 52.36469), 4326)))
        # returns: 1691.197905984
      end

      it "gets objects on layer 'tom.achtbanen' contained by 'tom.steden.utrecht'" do
        get "/layers/tom.achtbanen/objects?in=tom.steden.utrecht"
        last_response.status.should == 200
        last_response.header["X-Result-Count"].to_i.should == 2
        body_json(last_response)[:features].map {|f|
          f[:properties][:cdk_id]
        }.sort.should == ['tom.achtbanen.4', 'tom.achtbanen.5']
      end

      it "gets objects on layer 'tom.steden' containing 'tom.achtbanen.4'" do
        get "/layers/tom.steden/objects?contains=tom.achtbanen.4"
        last_response.status.should == 200
        last_response.header["X-Result-Count"].to_i.should == 1
        body_json(last_response)[:features][0][:properties][:cdk_id].should == 'tom.steden.utrecht'
      end

      it "gets one page of objects and object count" do
        get "/objects?title=spinnen"
        last_response.status.should == 200
        last_response.header["X-Result-Count"].to_i.should == 1
        body_json(last_response)[:features][0][:properties][:title].should ==
            'Het Grote Spinnen- en insectenimperium'
      end

      it "gets objects within bounding box" do
        get "/objects?bbox=52.38901,4.79519,52.35191,5.01135"
        last_response.status.should == 200
        last_response.header["X-Result-Count"].to_i.should == 2
        body_json(last_response)[:features][0][:properties][:cdk_id].should == 'bert.dierenwinkels.1'
        body_json(last_response)[:features][1][:properties][:cdk_id].should == 'tom.achtbanen.2'
      end
      it "gets one object with icon = 🐟" do
        get URI::encode("/objects?bert.dierenwinkels::icon=🐟")
        last_response.status.should == 200
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
      it "uses Accept header to get RDF/Turtle of /objects" do
        get "/objects", nil, {'HTTP_ACCEPT' => "text/turtle"}
        last_response.status.should == 200
        last_response.header['Content-Type'].should == 'text/turtle'
      end

      it "uses Accept header to get JSON-LD of /objects" do
        get "/objects", nil, {'HTTP_ACCEPT' => "application/ld+json"}
        last_response.status.should == 200
        last_response.header['Content-Type'].should == 'application/json'
        body_json(last_response).has_key?(:@context).should == true
      end


      it "checks if pagination Link headers are set for query on multiple layers" do
        get "/objects?layer=rutger.openingstijden,bert.dierenwinkels&per_page=3&page=2"
        last_response.status.should == 200
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
        last_response.status.should == 200
        # TODO: check endpoint content
      end

      it "gets all admin owners" do
        get "/owners?admin=true"
        last_response.status.should == 200
        last_response.header["X-Result-Count"].to_i.should == 2
      end

      it "gets all non-admin owners" do
        get "/owners?admin=false"
        last_response.status.should == 200
        last_response.header["X-Result-Count"].to_i.should == 2
      end

      it "gets all authoritative layers" do
        get "/layers?authoritative=true"
        last_response.status.should == 200
        last_response.header["X-Result-Count"].to_i.should == 1
      end

      it "gets all non-authoritative layers" do
        get "/layers?authoritative=false"
        last_response.status.should == 200
        last_response.header["X-Result-Count"].to_i.should == 3
      end

      object_count = 0
      it "gets all objects and object count" do
        get "/objects?count&per_page=250"
        last_response.status.should == 200
        object_count = body_json(last_response)[:features].length
        last_response.header["X-Result-Count"].to_i.should == object_count

        # Apparently, rspec sets hostname to 'example.org'
        last_response.header["Link"].should ==
            '<http://example.org/objects?count&page=1&per_page=250>; rel="last"'
      end

      it "gets one page of objects and object count" do
        get "/objects?count"
        last_response.status.should == 200
        last_response.header["X-Result-Count"].to_i.should == object_count
        last_response.header["Link"].should == [
          '<http://example.org/objects?count&page=3&per_page=10>; rel="last"',
          '<http://example.org/objects?count&page=2&per_page=10>; rel="next"'
        ].join(', ')
      end

      it "gets owners of layer 'tom.achtbanen'" do
        get "/layers/tom.achtbanen/owners"
        last_response.status.should == 200
        body_json(last_response).length.should == 1
        body_json(last_response)[0][:name].should == 'tom'
      end

      it "gets layers of owner 'tom'" do
        get "/owners/tom/layers"
        last_response.status.should == 200
        body_json(last_response)[:features].length.should == 2
      end

      it "gets bounding boxes of all layers" do
        get "/layers"
        last_response.status.should == 200
        all_polygons = body_json(last_response)[:features].map {|f| f[:geometry][:type] == 'Polygon' }.inject(:&)
        all_polygons.should == true
      end

      it "calls DELETE /layers and checks if response is 405 Method Now Allowed" do
        delete "/layers"
        last_response.status.should == 405
      end
    end

    describe "DELETE" do
      
      it "deletes single object 'bert.dierenwinkels.1'" do
        header "X-Auth", $bert_key
        delete "/objects/bert.dierenwinkels.1"
        last_response.status.should == 204
        last_response.body.should == ''
      end

      it "checks if 'bert.dierenwinkels.1' is moved to layer 'none' and still has data on 'rutger.openingstijden" do
        get "/objects/bert.dierenwinkels.1"
        last_response.status.should == 200
        body_json(last_response)[:features][0][:properties][:layer].should == 'none'
        tot = body_json(last_response)[:features][0][:properties][:layers][:'rutger.openingstijden'][:data][:tot]
        tot.should == '🕙'
      end

      it "deletes data on layer 'rutger.openingstijden' on single object 'bert.dierenwinkels.1'" do
        header "X-Auth", $citysdk_key
        delete "/objects/bert.dierenwinkels.1/layers/rutger.openingstijden"
        last_response.status.should == 204
        last_response.body.should == ''
      end

      it "checks if object 'bert.dierenwinkels.1' is deleted" do
        get "/objects/bert.dierenwinkels.1"
        last_response.status.should == 404
        body_json(last_response).should == {error: "Object not found: 'bert.dierenwinkels.1'"}
      end

      it "deletes layer 'bert.dierenwinkels'" do
        header "X-Auth", $citysdk_key
        delete "/layers/bert.dierenwinkels"
        last_response.status.should == 204
        last_response.body.should == ''
      end

      it "checks if all objects with data on 'rutger.openingstijden' are on layer 'none' and 'tom.achtbanen'" do
        get "/layers/rutger.openingstijden/objects"
        last_response.status.should == 200
        last_response.header["X-Result-Count"].to_i.should == 5
        body_json(last_response)[:features].map {|f| f[:properties][:layer] }.sort.should ==
          ['none', 'none', 'tom.achtbanen', 'tom.achtbanen', 'tom.achtbanen']
      end

      it "deletes owner 'rutger'" do
        header "X-Auth", $citysdk_key
        delete "/owners/rutger"
        last_response.status.should == 204
        last_response.body.should == ''
      end

      it "checks if orphaned objects are correctly deleted" do
        delete "/objects/bert.dierenwinkels.3"
        last_response.status.should == 404
        body_json(last_response).should == {error: "Object not found: 'bert.dierenwinkels.3'"}
      end

      it "deletes owner 'bert'" do
        header "X-Auth", $citysdk_key
        delete "/owners/bert"
        last_response.status.should == 204
        last_response.body.should == ''
      end

      it "deletes owner 'tom'" do
        header "X-Auth", $citysdk_key
        delete "/owners/tom"
        last_response.status.should == 204
        last_response.body.should == ''
      end

      it "checks whether all objects are deleted" do
        get "/objects"
        last_response.status.should == 200
        last_response.header["X-Result-Count"].to_i.should == 0
        body_json(last_response)[:features].length.should == 0
      end
      
    end


end