---
title: Apps
---

Ontwikkelaars makkelijk apps maken met de api, data stad dit dat.

<ul class="apps">
{% for app in site.data.endpoint.apps %}
<li style="background-image: url({{ site.baseurl }}/apps/{{ app.name }}.png)">
  <a href="{{ site.baseurl}}/apps#{{ app.name }}">{{ app.title }}</a>
</li>
{% endfor %}
</ul>