---
title: About
---

The CitySDK Linked Data API is developed as part of the European [CitySDK](http://www.citysdk.eu/) project.
It provides for a unified and direct access to (open) data, with an interface allowing for writing data as well. 
As such it is an enabler for the 'read-write city' where, conceivably, we don't only read the state of city element, but can also alter that state. 

It is designed to work closely with other open source projects as OpenTripPlanner, OpenTripPlanner Analyst, Open311, GTFS, and OpenStreetMap. 
Based on objects linked to a geometry, the API provides for a linked data (JSON-LD) view of the added data; one query about one object provides results from multiple datasets, annotated using semantic web technologies.

<!-- Hier een diagram van de werking.. -->

## How to join?

Would your city like to open up its data and services to a big European developer community by joining CitySDK? Get in touch with the [owners](mailto:{{ site.data.endpoint.email }}) of this endpoint or the project management of CitySDK at [Forum Virium Helsinki](http://www.citysdk.eu/partners/forum-virium/).


# Endpoints in other cities

* [Amsterdam (NL)](http://dev.citysdk.waag.org)
* [Helsinki (FI)](http://144.76.172.136/)
* [Istanbul (TR)](http://devcitysdk.ibb.gov.tr)
* [Manchester (UK)](http://dev.citysdk.futureeverything.org/data)
* [Province of Rome (IT)](http://dev.citysdk-mobility.provincia.roma.it)
* [Lamia (GR)](http://dev.citysdk.waag.org)



## Endpoints other CitySDK APIs

* [Helsinki Participation Endpoint](http://dev.hel.fi/apis/issuereporting)
* [Province of Rome Participation](http://nodeshot.readthedocs.org/en/latest/topics/open311.html)
* [Lamia Participation Endpoint](https://participation.citysdk.lamia-city.gr/rest)
* [CitySDK Tourism API's](http://citysdk.ist.utl.pt/index.html)



# FAQ

#### What is the CitySDK Linked Data API?

It is a web service offering unified and direct access to open data from government, commercial and crowd sources alike. The web service is a standard adopted by 6 European cities.

#### What does the CitySDK Linked Data API do?

The Linked Data API makes data available in five steps:

1. It collects data or web services from different sources;
2. It describes the data;
3. It links the data to reference datasets when applicable (e.g. from Cadastre or OSM);
4. It offers the data as a unified service to other applications (API);
5. It allows those applications to annotate and enrich the data.

Independent of file format, refresh rate or granularity open data is easily accessible for commercial use, research and software developers. 

#### Which datasets are available in this API?

Via the menu link [Data]({{ site.baseurl }}/data) you can access a list with all datasets, with a direct link to a sample query in JSON and a map view.


#### Can you add dataset X?

Yes, probably. Datasets need to be open and have a geolocation. You can send an [e-mail](mailto:{{ site.data.endpoint.email }}) to request the addition of a dataset. You can also ask for an account and add the dataset yourself using our (basic) CMS or API.

#### Who maintains the CitySDK LD codebase?


[Waag Society](http://waag.org) maintains the codebase on [GitHub]({{ site.data.endpoint.github }}).

#### Who runs this API instance?

This endpoint is hosted and maintained by [{{ site.data.endpoint.organization }}]({{ site.data.endpoint.homepage }}).

Contact us via [e-mail](mailto:{{ site.data.endpoint.email}}).

For more information on the project and the partner cities, visit the [project website](http://www.citysdk.eu).

#### What are the terms & conditions?
This service is available, for now, with a ‘best effort SLA’ and a fair-use policy. A sustainable-hosted instance of the API is 
in preparation.

#### Other questions

Is your question missing? Send us an [e-mail](mailto:{{ site.data.endpoint.email }}).