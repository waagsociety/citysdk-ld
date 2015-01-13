---
---

API, real-time data city services open data
GeoJSON and JSON-LD

A list of available data in this endpoint can be seen via [data]({{ site.baseurl }}/data) and the [map viewer]({{ site.baseurl }}/map).

## Data examples

<ul id="apps">
<li>
  <h4>Explore available data sets</h4>
  <a class="image-link" href="{{ site.baseurl}}/map#{{ site.data.endpoint.examples[0].url }}" style="background-image: url({{ site.baseurl }}/images/apps/map.jpg)"></a>
</li>
{% for app in site.data.endpoint.apps limit: 4 %}
<li>
  <h4>{{ app.title }}</h4>
  <a class="image-link" href="{{ site.baseurl}}/apps#{{ app.name }}" style="background-image: url({{ site.baseurl }}/images/apps/{{ app.name }}.jpg)"></a>
</li>
</a>
{% endfor %}
</ul>

## Project CitySDK

CitySDK is creating a toolkit for the development of digital services within cities. With open and interoperable digital service interfaces, CitySDK enables a more efficient utilisation of the expertise and know-how of developer communities.

See the [CitySDK project website](http://www.citysdk.eu/) for a comprehensive overview of the complete CitySDK toolkit.