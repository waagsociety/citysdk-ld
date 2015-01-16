---
leaflet: true
d3: true
---

# CitySDK Linked Data API

An API for the distribution and annotation of open data. With the CitySDK Linked Data API, a city has a simple-to-use interface to all its data — it makes city services easier to implement, data easier to distribute, and applications easier to build, and works for both real-time and static data sets.

This website contains information about the CitySDK Linked Data API and the [datasets available]({{ site.baseurl }}/map) in the __{{ site.data.endpoint.instance }} instance__ of the API, hosted by [{{ site.data.endpoint.organization }}]({{ site.data.endpoint.homepage }}). The CitySDK LD API is an [open source project]({{ site.data.endpoint.github }}), and __easy to install in any city__, read the [docs]({{ site.baseurl }}/docs) to see how!

<div id="apps">
  <h4>Explore available data sets</h4>
  <a class="wide-image-link" href="{{ site.baseurl}}/map" style="background-image: url({{ site.baseurl }}/images/apps/map-wide.jpg)"></a>
  {% for app in site.data.endpoint.apps limit: 0 %}
  <h4>{{ app.title }}</h4>
  <a class="wide-image-link" href="{{ site.baseurl}}/apps#{{ app.name }}" style="background-image: url({{ site.baseurl }}/images/apps/{{ app.name }}-wide.jpg)"></a>
  {% endfor %}
</div>

## How to join?

Would your city like to open up its data and services to a big European developer community by joining CitySDK? Get in touch with the [owners](mailto:{{ site.data.endpoint.email }}) of this endpoint or the project management of CitySDK at [Forum Virium Helsinki](http://www.citysdk.eu/partners/forum-virium/).

## Project CitySDK

The CitySDK Linked Data API is part of CitySDK, a European Union project. CitySDK is a toolkit for the development of digital services within cities. With open and interoperable digital service interfaces, CitySDK enables a more efficient utilisation of the expertise and know-how of developer communities.

See the [CitySDK project website](http://www.citysdk.eu/) for a comprehensive overview of the complete CitySDK toolkit.

#### CitySDK APIs in other cities

The map below shows the European cities in which the CitySDK Linked Data API and the other [CitySDK APIs](http://www.citysdk.eu/citysdk-toolkit/components-of-the-toolkit/) are currently deployed — click on a CitySDK city for details about the city's APIs.

<div id="map">
</div>
<script>
  var tileUrl = "{{ site.data.endpoint.tiles }}",
      color = '{{ site.data.style.font-color }}',
      brandColor = '{{ site.data.style.brand-color }}',
      linkColor = '{{ site.data.style.link-color }}',

      map = L.map('map', {
        zoomControl: false
      }),
      osmAttrib = 'Map data © OpenStreetMap contributors',
      tileLayer = new L.TileLayer(tileUrl, {
        attribution: osmAttrib
      }).addTo(map);

  // Disable map interaction
  map.dragging.disable();
  map.touchZoom.disable();
  map.doubleClickZoom.disable();
  map.scrollWheelZoom.disable();
  map.boxZoom.disable();
  map.keyboard.disable();

  var pointStyle = {
    radius: 9,
    color: color,
    fillColor: linkColor,
    weight: 2,
    opacity: 1,
    fillOpacity: 1
  };

  function popup(feature) {
    var apiList = [];
    for (var type in feature.properties.apis) {
      var title = "Linked Data API";
      if (type === "participation") {
        title = "Open311 Participation API"
      } else if (type === "tourism") {
        title = "Tourism API";
      }
      apiList.push("<li><a href='" + feature.properties.apis[type] + "'>" + title + "</a></li>");
    }
    return feature.properties.title + ":"
        + "<ul>" + apiList.join('') + "</ul>";
  }

  d3.json("{{ site.baseurl}}/map/endpoints.json", function(json) {
    var geojson = new L.geoJson(json, {
      onEachFeature: function (feature, layer) {
        layer.bindPopup(popup(feature));
      },
      pointToLayer: function (feature, latlng) {
        return L.circleMarker(latlng, pointStyle);
      }
    }).addTo(map);
    map.fitBounds(geojson.getBounds());
  });
</script>
