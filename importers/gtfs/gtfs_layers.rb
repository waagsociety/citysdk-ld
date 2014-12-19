module GTFS_Import

  # make the gtfs layers if they exist, clear them (or not)
  def self.make_clear_layers(clear=true)
    GTFS_Import::connect
    if not $api.authenticate($EP_user,$EP_pass)
      puts "Error authenticating with API"
      exit!(-1)
    end

    begin
      ret = api.get('/layers/gtfs.stops')
      a = api.delete('/layers/gtfs.stops/objects') if clear
    rescue CitySDK::HostException => e
      api.post("/layers",@@gtfs_layers[:stops])
    end

    begin
      ret = api.get('/layers/gtfs.routes')
      api.delete('/layers/gtfs.routes/objects') if clear
    rescue CitySDK::HostException
      api.post("/layers",@@gtfs_layers[:routes])
    end

    begin
      ret = api.get('/layers/gtfs.routes.stops')
    rescue CitySDK::HostException
      api.post("/layers",@@gtfs_layers[:routes_stops])
    end

    begin
      ret = $api.get('/layers/gtfs.routes.schedule')
    rescue CitySDK::HostException
      $api.post("/layers",@@gtfs_layers[:routes_schedule])
    end

    begin
      ret = $api.get('/layers/gtfs.stops.schedule')
    rescue CitySDK::HostException
      $api.post("/layers",@@gtfs_layers[:stops_schedule])
    end


    # begin
    #   ret = $api.get('/layers/gtfs.stops.routes')
    # rescue CitySDK::HostException
    #   $api.post("/layers",@@gtfs_layers[:stops_routes])
    # end

    begin
      ret = $api.get('/layers/gtfs.stops.now')
    rescue CitySDK::HostException
      $api.post("/layers",@@gtfs_layers[:stops_now])
    end


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
    context: {},
    fields: [
        {
          name: "wheelchair_boarding",
          type: 'gtfs:wheelchairBoardingStatus',
          equivalent_property: 'gtfs:wheelchairBoarding',
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
      ]
  },

  routes: {
      name: "gtfs.routes",
      owner: "citysdk",
      title: "PTRoutes",
      description: "Public transport routes.",
      data_sources: ["http://gtfs.ovapi.nl/new/gtfs-nl.zip"],
      category: "mobility",
      subcategory: "public_transport",
      rdf_type: "gtfs:Route",
      rdf_prefixes: {gtfs: 'http://vocab.gtfs.org/terms#'},
      licence: "CC0",
      fields: [
        {
          name: "agency_id",
          equivalent_property: 'gtfs:agency',
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
          equivalent_property: 'gtfs:shortName',
          description: "Short name given to a route"
        },
        {
          name: "long_name",
          type: "xsd:string",
          equivalent_property: 'gtfs:longName',
          description: "Long name given to a route"
        },
        {
          name: "route_type",
          type: "gtfs:RouteType",
          equivalent_property: 'gtfs:routeType',
          description: "Describes the type of transportation used on a route"
        }
      ],
      context: {
      }
    },

    routes_stops: {
      name: "gtfs.routes.stops",
      owner: "citysdk",
      title: "PTStopsForRoute",
      description: "Public transport stops on routes.",
      data_sources: ["http://gtfs.ovapi.nl/new/gtfs-nl.zip"],
      category: "mobility",
      subcategory: "public_transport",
      rdf_type: "gtfs:Stop",
      rdf_prefixes: {
        gtfs: 'http://vocab.gtfs.org/terms#'
      },
      licence: "CC0",
      depends: "gtfs.routes",
      webservice_url: "CDK://gtfs.routes.stops",
      fields: [],
      context: {}
    },

    routes_schedule: {
      name: "gtfs.routes.schedule",
      owner: "citysdk",
      title: "PTScheduleForRoute",
      description: "Schedules for routes.",
      data_sources: ["http://gtfs.ovapi.nl/new/gtfs-nl.zip"],
      category: "mobility",
      subcategory: "public_transport",
      rdf_type: "cdk:Schedule",
      rdf_prefixes: {
        gtfs: 'http://vocab.gtfs.org/terms#'
      },
      licence: "CC0",
      depends: "gtfs.routes",
      webservice_url: "CDK://gtfs.routes.schedule",
      fields: [],
      context: {}
    },

    stops_schedule: {
      name: "gtfs.stops.schedule",
      owner: "citysdk",
      title: "PTScheduleForStop",
      description: "Schedules for stops.",
      data_sources: ["http://gtfs.ovapi.nl/new/gtfs-nl.zip"],
      category: "mobility",
      subcategory: "public_transport",
      rdf_type: "cdk:Schedule",
      rdf_prefixes: {
        gtfs: 'http://vocab.gtfs.org/terms#'
      },
      licence: "CC0",
      depends: "gtfs.stops",
      webservice_url: "CDK://gtfs.stops.schedule",
      fields: [],
      context: {}
    },
    
    stops_routes: {
      name: "gtfs.stops.routes",
      owner: "citysdk",
      title: "PTRoutesForStop",
      description: "Routes calling at stop.",
      data_sources: ["http://gtfs.ovapi.nl/new/gtfs-nl.zip"],
      category: "mobility",
      subcategory: "public_transport",
      rdf_type: "gtfs:Route",
      rdf_prefixes: {
        gtfs: 'http://vocab.gtfs.org/terms#'
      },
      licence: "CC0",
      depends: "gtfs.stops",
      webservice_url: "CDK://gtfs.stops.routes",
      fields: [],
      context: {}
    },
    
    stops_now: {
      name: "gtfs.stops.now",
      owner: "citysdk",
      title: "PTNowForStop",
      description: "Activity at stop in next hour.",
      data_sources: ["http://gtfs.ovapi.nl/new/gtfs-nl.zip"],
      category: "mobility",
      subcategory: "public_transport",
      rdf_type: "cdk:StopNow",
      rdf_prefixes: {
        gtfs: 'http://vocab.gtfs.org/terms#'
      },
      licence: "CC0",
      depends: "gtfs.stops",
      webservice_url: "CDK://gtfs.stops.now",
      fields: [],
      context: {}
    }

    
  }

end
