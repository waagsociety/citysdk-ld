module CitySDKLD

  def self.get_endpoint_data(query)
    config = CitySDKLD::App.get_config
    data = {
      url: "http://#{query[:host]}",
      swagger: "http://#{query[:host]}/swagger",
    }.merge(config[:endpoint]).merge({
      urls: {
        layers: '/layers{/layer}',
        owners: '/owners{/owner}',
        objects: '/objects{/cdk_id}',
      }
    })
  end

end



