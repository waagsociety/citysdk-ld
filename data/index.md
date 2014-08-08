---
layout: single
title : Data
d3    : true
---

# Data available via this endpoint

The following data is currently available via this CitySDK LD API instance:

<ul id="layers"></ul>
<script>

  var rows = {
    "description": "Description",
    "category": "Category",
    "organization": "Organization",
    "data_sources": "Data sources"
  };

  d3.json("{{ site.data.endpoint.endpoint }}/layers?per_page=999", function(data) {
    if (data.results.length) {
      var li = d3.select("#layers").selectAll("li")
          .data(data.results)
        .enter().append("li");
          //.sort(function(a, b) { return a.name > b.name; });

      li.append("h4")
        .html(function(d) { return d.name ;})

      li.append("a")
        .attr('class', 'sample-url')
        .html('Show data on map')
        .attr('href', function(d) {
          var sample_url = 'nodes?layer=' + d.name + '&per_page=10';
          if (d.sample_url) {
            sample_url = d.sample_url;
          }
          return '{{ site.baseurl }}/map-viewer/#' + sample_url;
        });

      var table = li.append("table").attr("class", "green-table");

      var tr = table.append("tr")
      tr.append("td").html('Layer name');
      tr.append("td").html(function(d) { return d.name; });

      Object.keys(rows).forEach(function(k) {
        var tr = table.append("tr")
        tr.append("td").html(rows[k] + ":");
        tr.append("td").html(function(d) { return d[k]; });
      });

    }
  });
</script>
