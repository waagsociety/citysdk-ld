---
---

API, real-time data city services open data
GeoJSON and JSON-LD

A list of available data in this endpoint can be seen via [data]({{ site.baseurl }}/data) and the [map viewer]({{ site.baseurl }}/map).

<ul class="apps">
<li style="background-image: url({{ site.baseurl }}/apps/map.jpg)">
  <a href="{{ site.baseurl}}/map#{{ site.data.endpoint.examples[0].url }}">Explore available data sets</a>
</li>
{% for app in site.data.endpoint.apps limit: 4 %}
<li style="background-image: url({{ site.baseurl }}/apps/{{ app.name }}.jpg)">
  <a href="{{ site.baseurl}}/apps#{{ app.name }}">{{ app.title }}</a>
</li>
{% endfor %}
</ul>

## Project CitySDK

CitySDK is creating a toolkit for the development of digital services within cities. With open and interoperable digital service interfaces, CitySDK enables a more efficient utilisation of the expertise and know-how of developer communities.

See the [CitySDK project website](http://www.citysdk.eu/) for a comprehensive overview of the complete CitySDK toolkit.