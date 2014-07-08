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
        if layer
          object = CDKObject.where(cdk_id: CitySDKLD.cdk_id_from_id(layer.name, ce['id'])).first
          if object
            return self.updateObject(query,layer,object,ce) 
          else 
            return self.createObject(query,layer,ce)
          end
        else
          return self.createObject(query,self.createOrionLayer(ce),ce)
        end
        return { ngsiresult: "updateContext succes!!!"}
      end
    end

    def self.queryContext(query)
      return { ngsiresult: "queryContext succes!!!"}
    end


    def self.createObject(query,layer,data)
      @object = @@object.clone
      @object['properties']['title'] = @object['properties']['id'] = data['id']
      data['attributes'].each do |a|
        @object['properties']['data'][a['name']] = a['value']
      end
      query[:params][:layer] = layer[:name]
      query[:data] = @object
      CDKObject.execute_write(query)
    end




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

