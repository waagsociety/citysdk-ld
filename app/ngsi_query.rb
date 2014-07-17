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
      data = query[:data]
      data['contextElements'].each do |ce|
        layer = CDKLayer.where(rdf_type: 'orion:'+ce['type']).or(rdf_type: ce['type']).first
        if !layer
          layer = self.create_layer(ce, query) unless layer
          self.create_object(query,layer,ce)
        else
          object = CDKObject.where(cdk_id: CitySDKLD.cdk_id_from_id(layer.name, ce['id'])).first
          if object
            self.update_object(query,layer,object,ce) 
          else 
            self.create_object(query,layer,ce)
          end
        end        
      end
      return { ngsiresult: "updateContext succes!!!"}
    end

    def self.queryContext(query)
      return { ngsiresult: "queryContext succes!!!"}
    end


    def self.create_object(query,layer,data)
      @object = @@object.clone
      @object['properties']['title'] = @object['properties']['id'] = data['id']
      data['attributes'].each do |a|
        @object['properties']['data'][a['name']] = a['value']
      end
      q = query.dup
      q[:params][:layer] = layer[:name]
      q[:data] = @object
      CDKObject.execute_write(q)
    end
    
    
    def self.update_object(query,layer,object,data)
      newdata = {}
      data['attributes'].each do |a|
        newdata[a['name']] = a['value']
      end
      q = query.dup
      q[:params][:cdk_id] = object.cdk_id
      q[:params][:layer] = layer.name
      q[:data] = newdata
      q[:method] = :put
      CDKObjectDatum.execute_write(q)
    end
    
    
    def self.create_layer(data, query)
      layer = @@layer.dup
      layer['name'] += data['type'].downcase
      layer['title'] = data['type'] + " " + layer['title']
      layer['rdf_type'] = 'orion:' + data['type']
      layer['fields'] = []
      data['attributes'].each do |a|
        layer['fields'] << {
          name: a['name'],
          type: a['type'],
          description: ""
        }
      end
      q = query.dup
      q[:data] = layer
      CDKLayer.execute_write(q)
      CDKLayer.where(rdf_type: 'orion:'+data['type']).first
    end

    @@layer = {
      'name' => "ngsi.",
      'owner' => "citysdk",
      'title' => " orion ngsi layer",
      'description' => "System-generated, Fi-Ware Orion compatible data layer",
      'data_sources' => ["NGSI"],
      'rdf_type' => "",
      'category' => "none",
      'subcategory' => "",
      'licence' => "unspecified"
    }


    @@object = 
        {
          "type" => "Feature",
          "properties" => {
            "id" => nil,
            "title" => nil,
            "data" => {
            }
          },
          "geometry" => {
            "type" => "Point",
            "coordinates" => [4.90032,52.37278]
          }
        }




    @@updateContextResponse = {
        contextResponses: [
          {
            contextElement: {
              attributes: [
                  {
                      name: nil,
                      type: nil,
                      value: nil
                  } # etc
              ]
            }
          }
        ]
      }



  end

end

