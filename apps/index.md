---
title: Apps
---

The following apps and websites are built on top of the CitySDK LD API. Please have a look at the [available data sets]({{ site.baseurl}}/data) and [API documentation]({{ site.baseurl }}/docs) if you want to use API data in your own application.

<div id="apps">
{% for app in site.data.endpoint.apps %}
  <h4 id="{{ app.name }}">{{ app.title }}</h4>
  <div class="row">
    <div class="six columns">
      <p>{{ app.description }}</p>
      <p><ul><li><a href="{{ app.url }}">{{ app.url }}</a></li></ul></p>
    </div>
    <div class="six columns">
      <a class="high-image-link" href="{{ app.url }}" style="background-image: url({{ site.baseurl }}/images/apps/{{ app.name }}.jpg)"></a>
    </div>
  </div>
{% endfor %}
</div>
