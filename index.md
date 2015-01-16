---
---

###A real-time city data API (Amsterdam)

Makes services easier to implement, data easier to distribute and applications easier to build. A list of available data in this endpoint can be seen via [data]({{ site.baseurl }}/data) and the [map viewer]({{ site.baseurl }}/map).


<div id="apps">

  <h4>Explore available data sets</h4>
  <a class="wide-image-link" href="{{ site.baseurl}}/map#{{ site.data.endpoint.examples[0].url }}" style="background-image: url({{ site.baseurl }}/images/apps/map-wide.jpg)"></a>

  {% for app in site.data.endpoint.apps limit: 4 %}
  <h4>{{ app.title }}</h4>
  <a class="wide-image-link" href="{{ site.baseurl}}/apps#{{ app.name }}" style="background-image: url({{ site.baseurl }}/images/apps/{{ app.name }}-wide.jpg)"></a>
  {% endfor %}

</div>

### Project CitySDK

CitySDK is creating a toolkit for the development of digital services within cities. With open and interoperable digital service interfaces, CitySDK enables a more efficient utilisation of the expertise and know-how of developer communities.

See the [CitySDK project website](http://www.citysdk.eu/) for a comprehensive overview of the complete CitySDK toolkit.
