---
layout: single
title: App Gallery
---

# App Gallery

These applications use the CitySDK Linked Data API. Would you like your app listed here as well? Send us an [e-mail](mailto:{{ site.data.endpoint.email }}).

<table class="green-table">
  {% for item in site.data.endpoint.appgallery %}
  <tr class="alt first">
    <td><img src="{{ site.baseurl }}/img/icons/{{ item.icon }}"></td>
    <td>
      <strong>
      <a href="{{ item.url }}">{{ item.title }}</a>
      </strong>
      <br>
      {{ item.description }}
    </td>
  </tr>
  {% endfor %}
</table>
