---
title: Apps
---

Ontwikkelaars makkelijk apps maken met de api, data stad dit dat.

<div id="apps">
{% for app in site.data.endpoint.apps %}
<h5 id="{{ app.name }}">{{ app.title }}</h5>
<img src="{{ site.baseurl }}/apps/{{ app.name }}.jpg" />
<p>{{ app.description }}</p>
<p><a href="{{ app.url }}">{{ app.url }}</a></p>
{% endfor %}
</div>
