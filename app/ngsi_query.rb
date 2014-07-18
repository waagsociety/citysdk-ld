# encoding: UTF-8

module CitySDKLD


  class NGSI10
  
    def self.do_query(query) 
      case query[:path][-1]
      when :updateContext
        return self.updateContext(query)
      when :queryContext
        return self.queryContext(query)
      end
      return { ngsiresult: "unkown command"}
    end


    def self.updateContext(query)
      self.check_data_consistency(query)
      ctResponse = {contextResponses: [], statusCode: {code: "200", reasonPhrase: "OK"}}
      data = query[:data]
      data['contextElements'].each do |ce|
        layer = CDKLayer.where(rdf_type: 'orion:'+ce['type']).or(rdf_type: ce['type']).first
        if !layer
          layer = self.create_layer(ce, query)
          self.create_object(query,layer,ce)
        else
          object = CDKObject.where(cdk_id: CitySDKLD.cdk_id_from_id(layer.name, ce['id'])).first
          if object
            self.update_object(query,layer,ce,object) 
          else 
            self.create_object(query,layer,ce)
          end
        end
        ctResponse[:contextResponses] << ce
      end
      return ctResponse
    end
    
    
    def self.one_object(ce, object, layer, attributes)
      elm = {contextElement: {attributes: [], id: object[:title], isPattern: false, type: ce['type'] }, statusCode: {code: "200", reasonPhrase: "OK"} }
      odatum = CDKObjectDatum.get_from_object_and_layer(object.cdk_id, layer.id)
      odatum[:data].each do |k,v|
        elm[:contextElement][:attributes] << { name: k, value: v, type: @fieldTypes[layer.id][k] || 'unknown' } if attributes.blank? or attributes.include?(k)
      end
      elm
    end
    
    def self.one_entity(ce,layer,attributes)
      retvalue = []
      if ce['isPattern'] == 'true'
        objects = CDKObject.where(layer_id: layer.id, title: Regexp.new(ce['id']))
        objects.each do |o|
          retvalue << self.one_object(ce, o, layer, attributes)
        end
      else
        cdk_id = CitySDKLD.cdk_id_from_id(layer.name, ce['id'])
        object = CDKObject.where(cdk_id: cdk_id).first
        if object
          retvalue << self.one_object(ce, object, layer, attributes)
        end
      end
      retvalue
    end

    def self.queryContext(query)
      ctResponse = {contextResponses: []}
      data = query[:data]
      attributes = data['attributes']
      @fieldTypes = []
      data['entities'].each do |ce|
        layer = CDKLayer.where(rdf_type: 'orion:'+ce['type']).or(rdf_type: ce['type']).first
        if layer
          self.populate_field_types(layer) 
          ctResponse[:contextResponses] += self.one_entity(ce,layer,attributes)
        end
      end
      return { errorCode: { code: "404", reasonPhrase: "No context elements found" } } if ctResponse[:contextResponses].length == 0
      return ctResponse
    end

    def self.populate_field_types(l)
      return if @fieldTypes[l.id]
      layer = CitySDKLD.memcached_get(CDKLayer.memcached_key(l[:id].to_s))
      @fieldTypes[l[:id]] = {}
      layer[:fields].each { |f|
        @fieldTypes[l[:id]][f[:name]] = f[:type]
      }
    end
    
    
    def self.create_object(query,layer,data)
      object = { "type" => "Feature", "properties" => { "id" => nil, "title" => nil, "data" => { } }, "geometry" => { "type" => "Point", "coordinates" => [4.90032,52.37278] } }
      object["properties"]["title"] = object["properties"]["id"] = data['id']
      data['attributes'].each do |a|
        object["properties"]["data"][a['name']] = a['value']
        a['value'] = ""
      end
      q = query.dup
      q[:params] = query[:params].dup
      q[:params][:layer] = layer[:name]
      q[:data] = object
      CDKObject.execute_write(q)
    end
    
    
    def self.update_object(query,layer,data,object)
      newdata = {}
      data['attributes'].each do |a|
        newdata[a['name']] = a['value']
        a['value'] = ""
      end
      q = query.dup
      q[:params][:cdk_id] = object.cdk_id
      q[:params][:layer] = layer.name
      q[:data] = newdata
      q[:method] = :patch
      CDKObjectDatum.execute_write(q)
    end
    
    
    def self.create_layer(data, query)
      layer = {
        'name' => 'ngsi.'+data['type'].downcase,
        'title' => data['type'] + " orion ngsi layer",
        'rdf_type' => 'orion:' + data['type'],
        'fields' => [],
        'owner' => "citysdk",
        'description' => "System-generated, Fi-Ware Orion compatible data layer",
        'data_sources' => ["NGSI"],
        'category' => "none",
        'subcategory' => "",
        'licence' => "unspecified"
      }
      data['attributes'].each do |a|
        layer['fields'] << {
          name: a['name'],
          type: a['type'],
          description: ""
        }
      end
      q = query.dup
      q[:data] = layer
      q[:method] = :post
      CDKLayer.execute_write(q)
      CDKLayer.where(rdf_type: 'orion:'+data['type']).first
    end
    
    
    def self.check_data_consistency(query)
      data = query[:data]
      query[:api].error!("Error in NGSI data format", 422) if data['contextElements'].nil?
      data['contextElements'].each do |ce|
        query[:api].error!("Error in NGSI data format", 422) if ce['type'].blank? or ce['id'].blank?
      end
    end

  end

end

