---
title: Data
d3: true
---

In the CitySDK Linked Data API, data sets are called `layers`. Each layer can contain `objects`, and each `object` contains, per `layer`, key/value `data`. In the API, _real-world objects_ like buildings, bus stops and municipalities are represented by `objects`, which can contain `data` on one or more `layers`. This way, multiple data sets can tell something about one single `object`. The data model and concepts are explained in detail on the [About page]({{ site.baseurl}}/about), and in the project's [wiki]({{ site.data.endpoint.wiki }}).

The following `layers` are currently available via this CitySDK LD API instance. You can also view the results as JSON-LD using the [`/layers`]({{ site.data.endpoint.endpoint }}/layers?per_page=100) API.

<ul id="layers"></ul>
<script>
  d3.json("{{ site.data.endpoint.endpoint }}/layers?per_page=100", function(data) {
    if (data.features.length) {
      var li = d3.select("#layers").selectAll("li")
          .data(data.features)
        .enter().append("li");
          //.sort(function(a, b) { return a.properties.name > b.properties.name; });

      li.append("h4").append('pre')
        .html(function(d) { return d.properties.name ;})

      var table = li.append("table");

      var tr = table.append("tr")
      tr.append("td").html('Layer name:');
      tr.append("td").append('code').append('a').attr('href', function(d) {
        return '{{ site.data.endpoint.endpoint }}layers/' + d.properties.name;
      }).html(function(d) { return d.properties.name; });

      tr = table.append("tr")
      tr.append("td").html('Description:');
      tr.append("td").html(function(d) { return d.properties.description; });

      tr = table.append("tr")
      tr.append("td").html('Data:');
      tr.append("td").each(function(d) {
        d3.select(this)
        .append("a").attr('href', function(d) {
          var sample_url = 'layers/' + d.properties.name + '/objects?per_page=25';
          if (d.sample_url) {
            sample_url = d.sample_url;
          }
          return '{{ site.baseurl }}/map#' + sample_url;
        })
        .html('View on map');
      });

      tr = table.append("tr")
      tr.append("td").html('Category:');
      var td = tr.append("td");
      td.append('code').append('a').attr('href', function(d) {
        return '{{ site.data.endpoint.endpoint }}layers?category=' + d.properties.category;
      }).html(function(d) { return d.properties.category; });
      td.append('span').html(' / ');
      td.append('span').append('code').html(function(d) { return d.properties.subcategory; });

      tr = table.append("tr")
      tr.append("td").html('Owner:');
      tr.append("td").append('code')
          .append('a')
          .attr('href', function(d) { return '{{ site.data.endpoint.endpoint }}owners/' + d.properties.owner; })
          .html(function(d) { return d.properties.owner; });

      tr = table.append("tr")
      tr.append("td").html('Licence:');
      tr.append("td").each(function(d) {
        if (d.properties.licence.indexOf("http") == 0) {
          d3.select(this).append('a')
              .attr('href', d.properties.licence)
              .html(d.properties.licence);
        } else {
          d3.select(this).html(d.properties.licence);
        }
      });

      tr = table.append("tr")
      tr.append("td").html('Data sources:');
      tr.append("td").each(function(d) {
        var links = [];
        d.properties.data_sources.forEach(function(data_source) {
          var m = data_source.match(/:\/\/(.*?)\//);
          if (m && m[1]) {
            console.log(m[1])
            links.push('<a href="' + data_source + '">' + m[1] + '</a>');
          }
        });
        d3.select(this).html(links.join(', '));

      });
    }
  });
</script>
