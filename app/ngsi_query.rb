# encoding: UTF-8

module CitySDKLD


  class NGSI10
  
    def self.do_query(query) 
      @limit   = query[:params][:limit] ? [1000,query[:params][:limit].to_i].min : 20
      @offset  = query[:params][:offset] ? query[:params][:offset].to_i : 0
      @details = (query[:params][:details] and query[:params][:details] == "on") ? true : false
      case query[:method]
        when :post
          return self.post(query)
        when :put
          return self.put(query)
        when :get
          return self.get(query)
      end
      return { ngsiresult: "unkown command"}
    end

    def self.get(q)
      case q[:path][-2]
        when :contextEntityTypes
          return self.query_contextentity_types(q) if q[:params][:cetype]
        when :contextEntities
          return self.query_one_entity(q)    if q[:params][:entity]
        when :attributes
          return self.query_one_attribute(q) if q[:params][:entity] and q[:params][:attribute]
          return self.query_contextentity_types(q) if q[:params][:cetype] and q[:params][:attribute]
      end
      return { ngsiresult: "unkown command"}
    end
    
    def self.put(q)
      if q[:path][-1] == :attributes and q[:params][:entity] 
        return self.update_attributes_for_entity(q)
      end
      return { ngsiresult: "unkown command"}
    end
    
    def self.post(q)
      case q[:path][-1]
        when :updateContext
          return self.updateContext(q)
        when :queryContext
          return self.queryContext(q)
        when :subscribeContext 
          return { ngsiresult: "not yet implemented: " + q[:path][-1]}
        when :updateContextSubscription 
          return { ngsiresult: "not yet implemented: " + q[:path][-1]}
        when :unsubscribeContext
          return { ngsiresult: "not yet implemented: " + q[:path][-1]}
      end
      return { ngsiresult: "unkown command"}
    end
    
    
    def self.update_attributes_for_entity(q)
      data = q[:data]
      newdata = {}
      pattern = "(.*)\\.#{Regexp::quote(q[:params][:entity])}$"
      object = CDKObject.where(cdk_id: Regexp.new(pattern,Regexp::IGNORECASE)).first
      if object
        layer = CitySDKLD.memcached_get(CDKLayer.memcached_key(object.layer_id.to_s))
        data['attributes'].each do |a|
          newdata[a['name']] = a['value']
          a['value'] = ""
        end
        q = q.dup
        q[:params][:cdk_id] = object.cdk_id
        q[:params][:layer] = layer[:name]
        q[:data] = newdata
        q[:method] = :patch
        CDKObjectDatum.execute_write(q)
        data[:statusCode] = { code: "200", reasonPhrase: "OK"}
        return data
      else
        return { errorCode: { code: "404", reasonPhrase: "No context elements found" } }
      end
    end
    
    def self.updateContext(query)
      ctResponse = {contextResponses: [], statusCode: {code: "200", reasonPhrase: "OK"}}
      data = query[:data]
      if data['updateAction'] =~ /delete/i
        # delete attributes or contextentities
      else
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
      end
      return ctResponse
    end
    
    def self.query_one_entity(q)
      @fieldTypes = []
      r = get_one_entity({'id' => q[:params][:entity]},nil,nil)
      (r and r[0]) ? r[0] : { errorCode: { code: "404", reasonPhrase: "No context elements found" } }
    end
    
    def self.query_one_attribute(q)
      @fieldTypes = []
      r = get_one_entity({'id' => q[:params][:entity]},nil,nil)
      return { errorCode: { code: "404", reasonPhrase: "No context elements found" } } if r.nil?
      if r[0]
        r[0][:contextElement][:attributes].each do |a|
          if a[:name] == q[:params][:attribute]
            r[0][:attributes] = [a] 
            r[0].delete(:contextElement)
            return r[0]
          end
        end
      end
      { errorCode: { code: "404", reasonPhrase: "Attribute not found in context element" } }
    end

    def self.get_one_entity(ce,attributes, restriction)
      retvalue = []
      if ce['isPattern']
        pattern = "(.*)\\." + ce['id']
        objects = self.objects_select_filter(CDKObject.where(cdk_id: Regexp.new(pattern,Regexp::IGNORECASE)), restriction)
        @count = CDKObject.where(cdk_id: Regexp.new(pattern,Regexp::IGNORECASE)).count() if @details
        objects.each do |o|
          layer = CitySDKLD.memcached_get(CDKLayer.memcached_key(o.layer_id.to_s))
          self.populate_field_types(layer) 
          retvalue << self.get_one_object(ce, o, layer, attributes)
        end
      else
        pattern = "(.*)\\." + Regexp::quote(ce['id'])
        object = self.objects_select_filter( CDKObject.where(cdk_id: Regexp.new(pattern,Regexp::IGNORECASE)), restriction).first
        if object
          layer = CitySDKLD.memcached_get(CDKLayer.memcached_key(object.layer_id.to_s))
          self.populate_field_types(layer) 
          retvalue << self.get_one_object(ce, object, layer, attributes)
        end
      end
      retvalue
    end

    def self.get_one_layered_entity(ce,layer,attributes, restriction)
      retvalue = []
      if ce['isPattern']
        pattern = Regexp::quote(layer.name + ".") + ce['id']
        objects = self.objects_select_filter(CDKObject.where(layer_id: layer.id, cdk_id: Regexp.new(pattern,Regexp::IGNORECASE)), restriction)
        @count  = CDKObject.where(layer_id: layer.id, cdk_id: Regexp.new(pattern,Regexp::IGNORECASE)).count() if @details
        objects.each do |o|
          retvalue << self.get_one_object(ce, o, layer, attributes)
        end
      else
        cdk_id = CitySDKLD.cdk_id_from_id(layer.name, ce['id'])
        object = self.objects_select_filter(CDKObject.where(cdk_id: cdk_id), restriction).first
        if object
          retvalue << self.get_one_object(ce, object, layer, attributes)
        end
      end
      retvalue
    end

    def self.get_one_object(ce, object, layer, attributes)
      elm = {contextElement: {attributes: [], id: object[:title], isPattern: false, type: ce['type'] }, statusCode: {code: "200", reasonPhrase: "OK"} }
      odatum = CDKObjectDatum.get_from_object_and_layer(object.cdk_id, layer[:id])
      odatum[:data].each do |k,v|
        begin
          v = JSON.parse(v, symbolize_names: true)
        rescue
        end
        elm[:contextElement][:attributes] << { name: k, value: v, type: @fieldTypes[layer[:id]][k] || 'unknown'} if attributes.blank? or attributes.include?(k)
      end
      if object[:centr] =~ /POINT\(([\d\.]+)\s([\d\.]+)\)/
        elm[:contextElement][:attributes] << { name: 'geography', 
                                               value: "#{$2}, #{$1}", 
                                               type: 'coords', 
                                               metadatas: [ { 
                                                   name: "location", 
                                                   type: "string", 
                                                   value: "WSG84"
                                                 } 
                                               ]
                                              } if attributes.blank?
      end
      elm
    end
    
    
    def self.query_contextentity_types(q)
      layer = @count = nil
      @fieldTypes = []
      cetype = q[:params][:cetype]
      attrs = q[:params][:attribute] ? [ q[:params][:attribute] ] : nil
      ctResponse = {contextResponses: []}
      layer = CDKLayer.where(rdf_type: 'orion:'+cetype).or(rdf_type: cetype).first
      if layer
        self.populate_field_types(layer) 
        objects = self.objects_select_filter(CDKObject.where(layer_id: layer.id), nil)
        @count  = CDKObject.where(layer_id: layer.id).count() if @details
        objects.each do |o|
          ctResponse[:contextResponses] << self.get_one_object({'type'=>cetype}, o, layer, attrs)
        end
      end
      return { errorCode: { code: "404", reasonPhrase: "No context elements found" } } if ctResponse[:contextResponses].length == 0
      ctResponse[:errorCode] = {code: 200, reasonPhrase: "OK", details: "Count: #{@count}" } if @count
      return ctResponse
    end


    def self.queryContext(query)
      layer = @count = nil
      @fieldTypes = []
      ctResponse = {contextResponses: []}
      data = query[:data]
      attributes = data['attributes']
      data['entities'].each do |ce|
        if ce['type']
          layer = CDKLayer.where(rdf_type: 'orion:'+ce['type']).or(rdf_type: ce['type']).first
          if layer
            self.populate_field_types(layer) 
            ctResponse[:contextResponses] += self.get_one_layered_entity(ce,layer,attributes,data['restriction'])
          end
        else
          # typeless query
          ctResponse[:contextResponses] += self.get_one_entity(ce,attributes,data['restriction'])
        end
      end
      return { errorCode: { code: "404", reasonPhrase: "No context elements found" } } if ctResponse[:contextResponses].length == 0
      ctResponse[:errorCode] = {code: 200, reasonPhrase: "OK", details: "Count: #{@count}" } if @count
      return ctResponse
    end

    def self.populate_field_types(l)
      # cache field types to reduce db queries
      return if @fieldTypes[l[:id] || l['id']]
      layer = CitySDKLD.memcached_get(CDKLayer.memcached_key(l[:id].to_s))
      @fieldTypes[l[:id]] = {}
      layer[:fields].each { |f|
        @fieldTypes[l[:id]][f[:name]] = f[:type]
      }
    end
    
    def self.create_object(query,layer,data)
      object = { "type" => "Feature", "properties" => { "id" => nil, "title" => nil, "data" => { } }, 
                 "geometry" => { "type" => "Point", "coordinates" => [4.90032,52.37278] } 
               }
      object["properties"]["title"] = object["properties"]["id"] = data['id']
      data['attributes'].each do |a|
        object["properties"]["data"][a['name']] = a['value']
        a['value'] = "" # empty values for response object
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
    
    
    def self.polygon(vertices)
      ret = ''
      vertices.each do |v|
        ret << "," if ret.length > 0
        ret << v["longitude"] 
        ret << " " + v["latitude"] 
      end
      'POLYGON((' + ret + '))'
    end
    
    def self.objects_select_filter(dataset, restriction)
      dataset = dataset.select(:cdk_id, :layer_id, Sequel.as(Sequel.function(:ST_AsText, Sequel.function(:ST_Centroid, :geom)), :centr))
      if restriction
        restriction['scopes'].each do |s|
          if s["type"] == "FIWARE_Location"
            if s["value"]["polygon"] # p["vertices"], p["inverted"]
              p = self.polygon(s["value"]["polygon"]["vertices"])
              puts p
              if s["value"]["polygon"]["inverted"]
                dataset = dataset.where( Sequel.not(Sequel.function(:ST_Contains, Sequel.function(:ST_PolygonFromText,p), Sequel.function(:ST_Centroid, :geom))) )
              else
                dataset = dataset.where( Sequel.function(:ST_Contains, Sequel.function(:ST_PolygonFromText,p), Sequel.function(:ST_Centroid, :geom)) )
              end
            elsif s["value"]["circle"] # c["centerLatitude"], c["centerLongitude"], c["radius"], c["inverted"]
            end
          end
        end
      end
      dataset.offset(@offset).limit(@limit).order(:updated_at)
    end
  end

end

