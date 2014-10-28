module GTFS_Import

  def self.make_clear_layers(api)
    begin
      ret = api.get('/layers/gtfs.stops')
      api.delete('/layers/gtfs.stops/objects')
    rescue CitySDK::HostException
      api.post("/layers",@@gtfs_layers[:stops])
    end

    begin
      ret = api.get('/layers/gtfs.lines')
      api.delete('/layers/gtfs.lines/objects')
    rescue CitySDK::HostException
      api.post("/layers",@@gtfs_layers[:lines])
    end
 
    # begin
    #   ret = api.get('/layers/gtfs.lines.schedule')
    #   api.delete('/layers/gtfs.lines.schedule/objects')
    # rescue CitySDK::HostException
    #   api.post("/layers",@@gtfs_layers[:lines_schedule])
    # end
    #
    # begin
    #   ret = api.get('/layers/gtfs.stops.schedule')
    #   api.delete('/layers/gtfs.stops.schedule/objects')
    # rescue CitySDK::HostException
    #   api.post("/layers",@@gtfs_layers[:stops_schedule])
    # end
    #
    # begin
    #   ret = api.get('/layers/gtfs.stops.now')
    #   api.delete('/layers/gtfs.stops.now/objects')
    # rescue CitySDK::HostException
    #   api.post("/layers",@@gtfs_layers[:stops_now])
    # end
 

  end

  
@@gtfs_layers = {
  stops: {
    name: "gtfs.stops",
    owner: "citysdk",
    title: "PTStops",
    description: "Public transport stops and stations.",
    data_sources: ["http://gtfs.ovapi.nl/new/gtfs-nl.zip"],
    category: "mobility",
    subcategory: "public_transport",
    rdf_type: "gtfs:Stop",
    rdf_prefixes: {gtfs: 'http://vocab.gtfs.org/terms#'},
    licence: "CC0",
    fields: [
      {
        name: "wheelchair_boarding",
        type: 'gtfs:wheelchairBoardingStatus',
        equivalentProperty: 'gtfs:wheelchairBoarding',
        description: "0: no info; 1: at least on vehicle supports wheelchair boarding; 2: not possible"
      },
      {
        name: "location_type",
        type: "xsd:integer",
        description: "0: stop; 1: station"
      },
      {
        name: "stop_id",
        type: "xsd:string",
        description: "unique id for stop"
      },
      {
        name: "stop_name",
        type: "xsd:string",
        description: "name of stop"
      },
      {
        name: "parent_station",
        type: "xsd:string",
        description: "when location_type is 0: cdk_id of parent station or blank; when location_type is 1, this is blank"
      }
    ],
    '@context' => {
    }
  },
  lines: {
    name: "gtfs.lines",
    owner: "citysdk",
    title: "PTLines",
    description: "Public transport lines.",
    data_sources: ["http://gtfs.ovapi.nl/new/gtfs-nl.zip"],
    category: "mobility",
    subcategory: "public_transport",
    rdf_type: "gtfs:Route",
    rdf_prefixes: {gtfs: 'http://vocab.gtfs.org/terms#'},
    licence: "CC0",
    fields: [
      {
        name: "agency_id",
        equivalentProperty: 'gtfs:agency',
        type: "gtfs:Agency",
        description: "ID of agency running this line"
      },
      {
        name: "route_from",
        type: "xsd:string",
        description: "Name of starting stop/station"
      },
      {
        name: "route_to",
        type: "xsd:string",
        description: "Name of end stop/station"
      },
      {
        name: "route_id",
        type: "xsd:string",
        description: "unique id for route"
      },
      {
        name: "short_name",
        type: "xsd:string",
        equivalentProperty: 'gtfs:shortName',
        description: "Short name given to a route"
      },
      {
        name: "long_name",
        type: "xsd:string",
        equivalentProperty: 'gtfs:longName',
        description: "Long name given to a route"
      },
      {
        name: "route_type",
        type: "gtfs:RouteType",
        equivalentProperty: 'gtfs:routeType',
        description: "Describes the type of transportation used on a route"
      }
    ],
    '@context' => {
    }
  }
}



end

