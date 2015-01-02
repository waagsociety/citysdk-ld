---
title: Data
d3: true
---

The following data is currently available via this CitySDK LD API instance:

[API call]({{ site.data.endpoint.endpoint }}/layers)

http://json-ld.org/playground/index.html#startTab=tab-normalized&json-ld=http://195.169.149.30/layers

<ul id="layers"></ul>
<script>

  var rows = {
    "description": "Description",
    "category": "Category",
    "organization": "Organization",
    "data_sources": "Data sources"
  };

  d3.json("{{ site.data.endpoint.endpoint }}/layers?per_page=999", function(data) {
    if (data.features.length) {
      var li = d3.select("#layers").selectAll("li")
          .data(data.features)
        .enter().append("li");
          //.sort(function(a, b) { return a.name > b.name; });

      li.append("h4")
        .html(function(d) { return d.properties.name ;})

      li.append("a")
        .attr('class', 'sample-url')
        .html('Show data on map')
        .attr('href', function(d) {
          var sample_url = 'layers/' + d.properties.name + '/objects?per_page=25';
          if (d.sample_url) {
            sample_url = d.sample_url;
          }
          return '{{ site.baseurl }}/map-viewer/#' + sample_url;
        });

      li.append("a")
        .attr('class', 'sample-url')
        .html('RDF triples on JSON-LD Playground')
        .attr('href', function(d) {
          return '{{ site.data.endpoint.jsonldplaygr }}{{ site.data.endpoint.endpoint }}layers/' + d.properties.name;
        });



      var table = li.append("table").attr("class", "green-table");

      var tr = table.append("tr")
      tr.append("td").html('Layer name');
      tr.append("td").html(function(d) { return d.properties.name; });

      Object.keys(rows).forEach(function(k) {
        var tr = table.append("tr")
        tr.append("td").html(rows[k] + ":");
        tr.append("td").html(function(d) { return d.properties[k]; });
      });

    }
  });
</script>
