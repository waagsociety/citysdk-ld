---
layout: default
title: Documentation
---

#Documentation

This unified REST API gives access to data from different sources available on a per-object basis. The JSON and RDF API is written in Ruby + Sinatra. Data is stored in a PostgreSQL/PostGIS database. Documentation and source code can all be found on GitHub and there’s also a Ruby API gem.

**This website contains endpoint specific information only**, mainly regarding the datasets available here. All general documentation on the API can be found on the wiki at the corresponding [GitHub Wiki]({{ site.data.endpoint.wiki }}).

Here's the docs! [swagger]({{ site.baseurl }}/swagger)
*To help you get started a Swagger implementation will be available soon.*

## Datasets in this endpoint

The [List of datasets]({{ site.baseurl }}/data) combined with the [Map Viewer]({{ site.baseurl }}/map) is the best tool to get a grip on the available open data:

- Each dataset in the List of Datasets has a link to the map viewer called **Show data on map** which gives you an instant view of a sample of datapoints in JSON with a corresponding view of points, lines or shapes on the map;
- The query field on the Map Viewer has a drop down menu as well with a number of example queries.


## Other endpoints

A project-wide [Discovery API](http://cat.citysdk.eu/) is available to see which CitySDK APIs are available for which geography/jurisdiction.