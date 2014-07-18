#encoding: utf-8

require 'spec_helper'
include Rack::Test::Methods


describe CitySDKLD::API do
  
  it "gets a session key for owner 'citysdk'" do
    header "CONTENT_TYPE", "application/json"
    get "/session?name=citysdk&password=ChangeMeNow"
    last_response.status.should == 200
    $citysdk_key = body_json(last_response)[:features][0][:properties][:session_key]
    $citysdk_key.should_not == nil
  end
  
  describe "NGSI10" do
    it "creates object of existing and non-existing type" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $citysdk_key
      post "/ngsi10/updateContext", read_test_data('ngsi_update.json')
      expect(body_json(last_response)[:statusCode][:code]).to eq("200")
    end


    it "update existing objects" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $citysdk_key
      json = read_test_data_json('ngsi_update.json')
      json[:contextElements] = [json[:contextElements][1]]
      json[:contextElements][0][:attributes][0][:value] = "234";
      post "/ngsi10/updateContext", json.to_json
      expect(last_response.status).to be(201)
      get "/objects/ngsi.room.room7"
      res = body_json(last_response)
      expect(res[:features][0][:properties][:layers][:"ngsi.room"][:data][:temperature]).to eq("234")
    end


    it "can query for existing objects" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $citysdk_key
      json = read_test_data('ngsi_query.json')
      post "/ngsi10/queryContext", json
      expect(body_json(last_response)[:contextResponses][0][:statusCode][:code]).to eq("200")
      expect(body_json(last_response)[:contextResponses][0][:contextElement][:attributes].length).to be(2)
    end

    it "can query for non-existing objects" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $citysdk_key
      json = read_test_data_json('ngsi_query.json')
      json[:entities][0][:type] = "nonexistantLayer"
      post "/ngsi10/queryContext", json.to_json
      expect(body_json(last_response)[:errorCode][:code]).to eq("404")
    end

    it "correctly handles non-existing object" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $citysdk_key
      json = read_test_data_json('ngsi_query.json')
      json[:entities][0][:id] = "nonexistantObject"
      post "/ngsi10/queryContext", json.to_json
      puts last_response.body
      expect(body_json(last_response)[:errorCode][:code]).to eq("404")
    end

  end

end

