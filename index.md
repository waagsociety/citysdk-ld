---
---

A list of available data in this endpoint can be seen via [data]({{ site.baseurl }}/data) and the [map viewer]({{ site.baseurl }}/map).

<ul class="apps">
{% for app in site.data.endpoint.apps limit: 5 %}
<li style="background-image: url({{ site.baseurl }}/apps/{{ app.name }}.png)">
  <a href="{{ site.baseurl}}/apps#{{ app.name }}">{{ app.title }}</a>
</li>
{% endfor %}
</ul>

## Project CitySDK

CitySDK is creating a toolkit for the development of digital services within cities. With open and interoperable digital service interfaces, CitySDK enables a more efficient utilisation of the expertise and know-how of developer communities.

See the [CitySDK project website](http://www.citysdk.eu/) for a comprehensive overview of the complete CitySDK toolkit.