---
layout:
---

var endpoint  = "{{ site.data.endpoint.endpoint }}",
    tileUrl = "{{ site.data.endpoint.tiles }}",
    latLng = [{{ site.data.endpoint.map.geometry.lat }}, {{ site.data.endpoint.map.geometry.lon }}],
    zoom = {{ site.data.endpoint.map.zoom }};
//
//     //hljs.initHighlightingOnLoad();
//
//     var spinnerOpts = {
//       lines: 12, // The number of lines to draw
//       length: 4, // The length of each line
//       width: 1, // The line thickness
//       radius: 3, // The radius of the inner circle
//       corners: 1, // Corner roundness (0..1)
//       rotate: 0, // The rotation offset
//       direction: 1, // 1: clockwise, -1: counterclockwise
//       color: '#111', // #rgb or #rrggbb
//       speed: 1, // Rounds per second
//       trail: 60, // Afterglow percentage
//       shadow: false, // Whether to render a shadow
//       hwaccel: false, // Whether to use hardware acceleration
//       className: 'spinner', // The CSS class to assign to the spinner
//       zIndex: 2e9, // The z-index (defaults to 2000000000)
//       left:5,
//       top: 0
//       };
//     var spinner = new Spinner(spinnerOpts)
//
// var map = L.map('map');
//
// var disableHashChange = false;
// var latLongLargeShown = false;
// var urlHistory = []; // Keep list of used URLs to show in drop down menu.
// var currentURL = "";
//
// // ================================================================================
// // Leaflet map initialization
// // ================================================================================
//
// var osmAttrib = 'Map data © OpenStreetMap contributors';
//
// // Base maps ===============
//
// var tileLayer = new L.TileLayer(tileUrl, {
//   minZoom: 4, maxZoom: 18,
//   opacity: 1,
//   attribution: osmAttrib
// }).addTo(map);
//
//     var lineStyle = {
//       color: "#CE2027",
//       weight: 3,
//       opacity: 0.90
//     };
//
//     var pointStyle = {
//       radius: 5,
//       //fillColor: "#ed7cff",
//       //color: "#000000",
//       weight: 1,
//       opacity: 1,
//       fillOpacity: 0.9
//     };
//
//     function onFeatureClick(e) {
//       feature = e.target.feature;
//       setNodeData(feature.properties);
//     }
//
//     function onEachFeature(feature, layer) {
//       layer.on('click', onFeatureClick);
//     }
//
//     var cdkLayer = new L.geoJson(null, {
//       style: lineStyle,
//       onEachFeature: onEachFeature,
//       pointToLayer: function (feature, latlng) {
//         return L.circleMarker(latlng, pointStyle);
//       }
//     }).addTo(map);
//
//     map.setView(latLng, zoom);
//
//     // ================================================================================
//     // CitySDK API data
//     // ================================================================================
//
//     function loadCitySDKData(url, isExample) {
//       hideDropdown();
//
//       if (!url) {
//         return;
//       }
//
//       // Sometimes you want to refresh to (real-time) data
//       // by resubmitting same url...
//       // Turn check for new url off for now!
//       // if (!url || url == currentURL) {
//       //   return;
//       // }
//       //currentURL = url;
//
//       var historyUrl = url;
//
//       disableHashChange = true;
//       window.location.hash = url;
//
//       spinner.spin(document.getElementById('busy'))
//
//       var http = 'http://',
//           https = 'https://';
//
//       if (url.substring(0, http.length) !== http && url.substring(0, https.length) !== https) {
//         url = endpoint + url;
//       }
//       url += (url.split('?')[1] ? '&':'?') + 'geom';
//       if( url.indexOf("per_page") == -1 ) {
//         url += '&per_page=100';
//       }
//
//       cdkLayer.clearLayers();
//
//       // TODO: also reject if request times out!
//       $.getJSON(url, function(data) {
//         // If data is returned, and data.results.length > 0,
//         // add URL to urlHistory
//         if ((data.results.length > 0) &! isExample) {
//           addHistory(historyUrl);
//           setDropdownHistory();
//         }
//
//          for (var i = 0; i < data.results.length; i++) {
//            var node = data.results[i];
//
//            if(node.geom) {
//              var geom = node.geom
//              delete node["geom"];
//              var feature = {
//                type: "Feature",
//                properties: node,
//                geometry: geom
//              };
//            } else if(node.bbox) {
//              var geom = node.bbox
//              delete node["bbox"];
//              var feature = {
//                type: "Feature",
//                properties: node,
//                geometry: geom
//              };
//
//            } else {
//              continue;
//            }
//            cdkLayer.addData(feature);
//          }
//          formatResult(data);
//
//          spinner.stop();
//
//          /*
//          We want to fit all the data on the map.
//          Normally, map.fitBounds(cdkLayer.getBounds())
//          would do. But the floatbox is obscuring part
//          of the map.
//          We must calculate the bounds of the data
//          and resize the width to include floatbox width
//          */
//
//          var dataBounds = cdkLayer.getBounds();
//          var southWest = dataBounds.getSouthWest();
//          var northEast = dataBounds.getNorthEast();
//          // TODO: Dit is dus NIET goed. Ik moet hier nog 'ns even goed over na gaan denken. Nu naar bed. Daag!
//
//          var lngScale = $("#map").width() / (($("#map").width() - ($("#floatbox").width() + 30)));
//
//          map.fitBounds([
//              [southWest.lat, southWest.lng],
//              [northEast.lat, (northEast.lng - southWest.lng) * lngScale + southWest.lng]
//          ]);
//
//        }).fail(function(e) {
//          if(e.responseText)
//        {
//            var data = $.parseJSON(e.responseText);
//                  formatResult(data)
//              }
//        else
//        {
//         $('#nodedata').html("unknown error (maybe server is unavailable / maybe the requested was not formatted correctly)")
//        }
//        spinner.stop();
//      });
//
//     }
//
//     $("#url").keyup(function(event) {
//       if(event.keyCode == 13){
//         var url = $("#url").val();
//         loadCitySDKData(url, false);
//       }
//     });
//
//     function formatResult(result) {
//       setNodeData(result);
//     }
//
//     function setNodeData(json) {
//       $('#nodedata').html(JSON.stringify(json, undefined, 2));
//       $('#nodedata').each(function(i, e) {hljs.highlightBlock(e)});
//     }
//
//     // ================================================================================
//     // Load #hash url on page load
//     // ================================================================================
//
//     window.onhashchange = function() {
//       if (!disableHashChange) {
//         var hash = window.location.hash;
//         if (hash.length > 1) {
//           var url = hash.substring(1);
//           if (url.substring(0, endpoint.length) == endpoint) {
//             $("#url").val(url.substring(endpoint.length + 1));
//           } else {
//             $("#url").val(url);
//           }
//           loadCitySDKData(url, false);
//         }
//       }
//       disableHashChange = false;
//     }
//
//     // Call functions on page load:
//     window.onhashchange();
//     //window.onresize();
//     $('#url').focus();
//
//     // ================================================================================
//     // Combobox functions
//     // ================================================================================
//
//     $('td.endpoint').click(function() {
//       $('#url').focus();
//     });
//
//     $("#show-dropdown").click(function() {
//       var n = $("tr.dropdown.hidden").length;
//       if (n > 0) {
//         showDropdown();
//       } else {
//         hideDropdown();
//       }
//     });
//
//     $("#urls table").on("click", "tr.dropdown", function(event){
//       var url = $(this).attr("data-url");
//       var isExample = $(this).attr("data-example");
//       hideDropdown();
//       $("#url").val(url);
//       loadCitySDKData(url, isExample === "true");
//     });
//
//     $(document).mouseup(function (e) {
//       var container = $("tr.dropdown");
//       if (!$("#show-dropdown").is(e.target) && container.has(e.target).length === 0) {
//         hideDropdown();
//       }
//     });
//
//     function showDropdown() {
//       $(".dropdown").removeClass("hidden");
//       setButtonType("#show-dropdown", "up");
//     }
//
//     function hideDropdown() {
//       $(".dropdown").addClass("hidden");
//       setButtonType("#show-dropdown", "down");
//     }
//
//     function addDropdownExamples() {
//
//       // Jekyll inserts examples from endpoint.yml:
//       // TODO: read examples from examples.json instead!
//       var examples = [
//         {% for example in site.data.endpoint.examples %}
//         {
//           url: "{{ example.url }}",
//           title: "{{ example.title }}"
//         },
//         {% endfor %}
//       ];
//
//       $.each(examples.slice(0).reverse(), function() {
//         var tr = "<tr class=\"example hidden dropdown\" data-example=\"true\" data-url=\"" + this.url + "\"><td colspan=\"5\">" + this.title + "</td></tr>";
//         //$('#input table').append($(tr));
//         $(tr).insertAfter($('#before_examples'));
//       });
//
//     }
//
//     function addHistory(url) {
//       var index = urlHistory.indexOf(url);
//       if (index >= 0) {
//         urlHistory.splice(index, 1);
//       }
//       urlHistory.push(url);
//
//       if (urlHistory.length > 10) {
//         urlHistory.shift();
//       }
//     }
//
//     function setDropdownHistory() {
//       $('tr.history').remove();
//       $.each(urlHistory.slice(0, -1), function(index) {
//         var cls = "history hidden dropdown";
//         if (index == 0) {
//           cls += " last_history";
//         }
//         var tr = "<tr class=\"" + cls + "\" data-url=\"" + this + "\"><td class=\"minimize endpoint\">{{ site.data.endpoint.endpoint }}</td><td class=\"fill\" colspan=\"4\"><span class=\"url\">" + this + "</span></td></tr>";
//         $(tr).insertAfter($('#before_history'));
//       });
//     }
//     addDropdownExamples();
//   });
//
//   function setButtonType(selector, type) {
//     if (type === "up") {
//       $(selector).removeClass("button-down");
//       $(selector).addClass("button-up");
//     } else { // type === "down"
//       $(selector).removeClass("button-up");
//       $(selector).addClass("button-down");
//     }
//   }
//
//   $.ajaxTransport("+*", function( options, originalOptions, jqXHR ) {
//     if($.browser.msie && window.XDomainRequest) {
//       var xdr;
//       return {
//         send: function( headers, completeCallback ) {
//           // Use Microsoft XDR
//           xdr = new XDomainRequest();
//           r = Math.round(Math.random() * 1000)
//           xdr.open("get", options.url + "&ienocache=" + r);
//           xdr.onload = function() {
//             if (this.contentType.match(/\/xml/)){
//               var dom = new ActiveXObject("Microsoft.XMLDOM");
//               dom.async = false;
//               dom.loadXML(this.responseText);
//               completeCallback(200, "success", [dom]);
//             } else {
//               completeCallback(200, "success", [this.responseText]);
//             }
//           };
//           xdr.onprogress = function() {
//           };
//           xdr.ontimeout = function() {
//             completeCallback(408, "error", ["The request timed out."]);
//           };
//           xdr.onerror = function(a,b) {
//             completeCallback(404, "error", ["The requested resource could not be found."]);
//           };
//           xdr.send();
//         },
//         abort: function() {
//           if(xdr)xdr.abort();
//         }
//       };
//     }
//   });
//