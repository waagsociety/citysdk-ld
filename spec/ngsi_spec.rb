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
      body_json(last_response)[:ngsiresult].should == "updateContext succes!!!"
    end


    it "update existing objects" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $citysdk_key
      json = read_test_data_json('ngsi_update.json')
      json[:contextElements] = [json[:contextElements][1]]
      json[:contextElements][0][:attributes][0][:value] = 200;
      post "/ngsi10/updateContext", json.to_json
      last_response.status.should == 201
      get "/objects/ngsi.room.room7"
      res = body_json(last_response)
      res[:features][0][:properties][:layers][:"ngsi.room"][:data][:temperature].should == "200"
    end

  end

end

