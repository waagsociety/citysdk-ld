#encoding: utf-8

require 'spec_helper'
include Rack::Test::Methods

describe CitySDKLD::API do

  it "can get a session key for owner 'citysdk'" do
    header "CONTENT_TYPE", "application/json"
    get "/session?name=citysdk&password=ChangeMeNow"
    status_should(last_response, 200)
    $key_citysdk = body_json(last_response)[:session_key]
    $key_citysdk.should_not == nil
  end

  describe "NGSI10" do
    it "can create objects of existing and non-existing type" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_citysdk
      post "/ngsi10/updateContext", read_test_data('ngsi_update.json')
      status_should(last_response, 201)
    end

    it "can update existing objects" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_citysdk
      json = read_test_data_json('ngsi_update.json')
      json[:contextElements] = [json[:contextElements][1]]
      json[:contextElements][0][:attributes][0][:value] = "234";
      post "/ngsi10/updateContext", json.to_json
      status_should(last_response, 201)
      get "/objects/ngsi.room.room7"
      body_json(last_response)[:features][0][:properties][:layers][:'ngsi.room'][:data][:temperature].should == "234"
    end

    it "can query for existing objects" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_citysdk
      json = read_test_data_json('ngsi_query.json')
      json.delete(:restriction)
      post "/ngsi10/queryContext", json.to_json
      body_json(last_response)[:contextResponses][0][:statusCode][:code].should == "200"
      body_json(last_response)[:contextResponses][0][:contextElement][:attributes].length.should == 4
    end

    it "correctly handles queries for objects of non-existing types" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_citysdk
      json = read_test_data_json('ngsi_query.json')
      json[:entities][0][:type] = "nonexistantLayer"
      post "/ngsi10/queryContext", json.to_json
      body_json(last_response)[:errorCode][:code].should == "404"
    end

    it "correctly handles queries for non-existing objects" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_citysdk
      json = read_test_data_json('ngsi_query.json')
      json[:entities][0][:id] = "nonexistantObject"
      post "/ngsi10/queryContext", json.to_json
      body_json(last_response)[:errorCode][:code].should == "404"
    end

    it "can query for objects through reg-exps" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_citysdk
      json = read_test_data_json('ngsi_query.json')
      json[:entities][0][:id] = "r.*"
      json[:entities][0][:isPattern] = true
      json.delete(:restriction)
      post "/ngsi10/queryContext", json.to_json
      expect(body_json(last_response)[:contextResponses].length).to be(2)
      json[:entities][0][:id] = ".*"
      post "/ngsi10/queryContext", json.to_json
      expect(body_json(last_response)[:contextResponses].length).to be(3)
      json[:entities][0][:id] = ".*7$"
      post "/ngsi10/queryContext", json.to_json
      expect(body_json(last_response)[:contextResponses].length).to be(1)
    end

    it "can perform typeless queries" do
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_citysdk
      json = read_test_data_json('ngsi_query.json')
      json[:entities][0][:id] = ".*"
      json[:entities][0][:isPattern] = true
      json[:entities][0].delete(:type)
      json.delete(:restriction)
      post "/ngsi10/queryContext", json.to_json
      expect(body_json(last_response)[:contextResponses].length).to be(4)
    end

    it "can GET single entity" do
      header "CONTENT_TYPE", "application/json"
      get "/ngsi10/contextEntities/Kamer11"
      res = body_json(last_response)
      res[:contextElement][:attributes][0][:value].should == "711"
    end

    it "can GET single attribute" do
      header "CONTENT_TYPE", "application/json"
      get "/ngsi10/contextEntities/Room7/attributes/temperature"
      body_json(last_response)[:attributes][0][:value].should == "234"
    end

    
    it "can query for context entity types" do
      header "CONTENT_TYPE", "application/json"
      get "/ngsi10/contextEntityTypes/Room"
      expect(body_json(last_response)[:contextResponses].length).to be(3)
    end

    it "can query for single attibute over all context entities of a type" do
      header "CONTENT_TYPE", "application/json"
      get "/ngsi10/contextEntityTypes/Room/attributes/pressure"
      obj = body_json(last_response)
      res = obj[:contextResponses][0][:contextElement]
      res = res[:attributes]
      expect(obj[:contextResponses].length).to be(3)
      expect(res.length).to be(1)
      res[0][:value].should == "620"
    end

    it "can update attibutes for an entity" do
      path = "/ngsi10/contextEntities/Kamer11/attributes/"
      header "CONTENT_TYPE", "application/json"
      header "X-Auth", $key_citysdk
      get path + "pressure"
      data = body_json(last_response)
      data[:attributes][0][:value].should == "711"
      data.delete(:statusCode)
      data[:attributes][0][:value] = "pipo"
      put path, data.to_json
      get path + "pressure"
      body_json(last_response)[:attributes][0][:value].should == "pipo"
    end

    it "can query for objects within polygon" do
      header "CONTENT_TYPE", "application/json"
      json = read_test_data_json('ngsi_query.json')
      json[:entities][0][:id] = ".*"
      json[:entities][0][:isPattern] = true
      post "/ngsi10/queryContext", json.to_json
      expect(body_json(last_response)[:contextResponses].length).to be(2)
      expect(body_json(last_response)[:contextResponses][0][:contextElement][:attributes].length).to be(4)
    end

    it "can query for objects outside polygon" do
      header "CONTENT_TYPE", "application/json"
      json = read_test_data_json('ngsi_query.json')
      json[:entities][0][:id] = ".*"
      json[:entities][0][:isPattern] = true
      json[:restriction][:scopes][0][:value][:polygon][:inverted] = true
      post "/ngsi10/queryContext", json.to_json
      expect(body_json(last_response)[:contextResponses].length).to be(1)
      body_json(last_response)[:contextResponses][0][:contextElement][:id].should == "http://rdf.citysdk.eu/ams/ngsi.room.room4"
    end

    it "can query for objects within radius from a point" do
      header "CONTENT_TYPE", "application/json"
      json = read_test_data_json('ngsi_query.json')
      json[:entities][0][:id] = ".*"
      json[:entities][0][:isPattern] = true
      json[:restriction][:scopes][0][:value] = {
        circle: {
          centerLatitude: 52.37277,
          centerLongitude: 4.90033,
          radius: 1000,
          inverted: false
        }
      }
      post "/ngsi10/queryContext", json.to_json
      expect(body_json(last_response)[:contextResponses].length).to be(2)
      expect(body_json(last_response)[:contextResponses][0][:contextElement][:attributes].length).to be(4)
    end

    it "can query for objects outside radius from a point" do
      header "CONTENT_TYPE", "application/json"
      json = read_test_data_json('ngsi_query.json')
      json[:entities][0][:id] = ".*"
      json[:entities][0][:isPattern] = true
      json[:restriction][:scopes][0][:value] = {
        circle: {
          centerLatitude: 52.37277,
          centerLongitude: 4.90033,
          radius: 10000,
          inverted: true
        }
      }
      post "/ngsi10/queryContext", json.to_json
      expect(body_json(last_response)[:contextResponses].length).to be(1)
      body_json(last_response)[:contextResponses][0][:contextElement][:id].should == "http://rdf.citysdk.eu/ams/ngsi.room.room4"
    end

    it "can subscribe to entities" do
      header "CONTENT_TYPE", "application/json"
      json = read_test_data_json('ngsi_query.json')
      json.delete(:restriction)
      json[:attributes] = ['temperature']
      json[:duration] = 'P1M'
      json[:notifyConditions] = [{type: 'ONCHANGE', condValues: ['PT10S']}]
      post "/ngsi10/subscribeContext", json.to_json

      # error because no reference
      body_json(last_response)[:errorCode][:code].should == '422'

      json[:reference] = 'http://0.0.0.0:9797'
      post '/ngsi10/subscribeContext', json.to_json

      body_json(last_response)[:subscribeResponse][:duration].should == 'P1M'
      $sub_id = body_json(last_response)[:subscribeResponse][:subscriptionId]
    end

    it "posts message in response to change" do
      header 'CONTENT_TYPE', 'application/json'
      header 'X-Auth', $key_citysdk
      post '/ngsi10/updateContext', read_test_data('ngsi_change.json')
      body_json(last_response)[:statusCode][:code].should == '200'
    end

    it 'can remove subscriptions' do
      header 'CONTENT_TYPE', 'application/json'
      post '/ngsi10/unsubscribeContext', {subscriptionId: $sub_id}.to_json
      body_json(last_response)[:statusCode][:code].should == '204'
    end

  end

end
