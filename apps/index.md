---
title: Apps
---

Ontwikkelaars makkelijk apps maken met de api, data stad dit dat.

<div id="apps">
{% for app in site.data.endpoint.apps %}
  <h4 id="{{ app.name }}">{{ app.title }}</h4>
  <div class="row">
    <div class="six columns">
      <p>{{ app.description }}</p>
      <p><ul><li><a href="{{ app.url }}">{{ app.url }}</a></li></ul></p>
    </div>
    <div class="six columns">
      <a class="high-image-link" href="{{ app.url }}" style="background-image: url({{ site.baseurl }}/images/apps/{{ app.name }}-high.jpg)"></a>
    </div>
  </div>
{% endfor %}
</div>
