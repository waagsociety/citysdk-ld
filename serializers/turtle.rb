# # encoding: UTF-8
#
# require_relative 'serializer.rb'
#
# module CitySDKLD
#
#   module Serializers
#
#     class TurtleSerializer < Serializer
#
#       FORMAT = :turtle
#       CONTENT_TYPE = 'text/turtle'
#
#       def start
#         @result = []
#         @prefixes = []
#         @prefixes << '@base <http://rdf.citysdk.eu/asd/> .'
#         CitySDKLD::PREFIXES.each do |prefix, iri|
#           @prefixes << "@prefix #{prefix}: <#{iri}> ."
#         end
#       end
#
#       def finish
#         (@prefixes.uniq + [''] + @result).join("\n")
#       end
#
#       def objects
#
#         @layers.each do |l, layer|
#           layer[:fields].each do |field|
#             @result << "<layers/#{l}/fields/#{field[:id]}>"
#             @result << "    :definedOnLayer <layers/#{l}> ;"
#
#             @result << "    rdf_type #{field[:type]} ;" if field[:type]
#             @result << "    rdfs:description #{field[:description].to_json} ;" if field[:description]
#             @result << "    xsd:language #{field[:lang].to_json} ;" if field[:lang]
#             @result << "    owl:equivalentProperty #{field[:eqprop]} ;" if field[:eqprop]
#             @result << "    :hasValueUnit #{field[:unit]} ;" if field[:unit]
#
#             @result << "    rdfs:subPropertyOf :layerProperty ."
#             @result << ""
#           end
#         end
#
#         first = true
#         @data.each do |object|
#           @result << "" unless first
#           @result << "<#{object[:cdk_id]}>"
#           @result << "    a :Object ;"
#           @result << "    :cdk_id #{object[:cdk_id].to_json} ;"
#           @result << "    dc:title #{object[:title].to_json} ;" if object[:title]
#           @result << "    geos:hasGeometry #{object[:geom].round_coordinates(Serializers::COORDINATE_PRECISION).to_json} ;" if object[:geom]
#           @result << "    :createdOnLayer <layers/#{object[:layer]}> ;"
#
#           if object.key? :layers
#             object[:layers].keys.each do |layer|
#               s = (layer == object[:layers].keys[-1]) ? '.' : ';'
#               @result << "    :layerOnObject <layers/#{layer}/objects/#{object[:cdk_id]}> #{s}"
#             end
#           end
#           @result << ""
#
#           if object.key? :layers
#             object[:layers].keys.each do |layer|
#               @result << "<layers/#{layer}/objects/#{object[:cdk_id]}>"
#               @result << "    a :LayerOnObject ;"
#               @result << "    :layerData <objects/#{object[:cdk_id]}/layers/#{layer}> ;"
#               @result << "    :createdOnLayer <layers/#{layer}> ."
#               #@result << "    dc:created \"<object datum created date>\"^^xsd:date ."
#
#               if @layers[layer][:@context]
#
#                 types = [':LayerData']
#                 types << @layers[layer][:rdf_type] if @layers[layer][:rdf_type]
#
#                 jsonld = {
#                   :@context => @layers[layer][:@context],
#                   :@id => ":objects/#{object[:cdk_id]}/layers/#{layer}",
#                   :@type => types
#                 }.merge object[:layers][layer][:data]
#                 graph = RDF::Graph.new << JSON::LD::API.toRdf(JSON.parse(jsonld.to_json))
#
#                 # Get layer prefixes from JSON-LD context
#                 # only add first-level values, if they
#                 # start with http and end with either # or /
#                 # Afterwards, merge layer prefixes with global
#                 # PREFIXES
#                 prefixes = @layers[layer][:@context].select { |prefix,iri|
#                   prefix != :"@base" and iri.is_a? String and
#                   iri.index("http") == 0 and ["/", "#"].include? iri[-1]
#                 }.merge PREFIXES
#
#                 graph.dump(:ttl, prefixes: prefixes).each_line do |line|
#                   # Turtle output of graph.dump contains both prefixes statements
#                   # Filter out prefixes, and add them to @prefixes and rest to @result
#                   if line.index("@prefix") == 0
#                     @prefixes << line.strip
#                   else
#                     @result << line.rstrip
#                   end
#                 end
#
#               end
#             end
#           end
#           first = false
#         end
#
#       end
#
#       def layers
#         first = true
#         @data.each do |layer|
#           @result << "" unless first
#           @result << "<layers/#{layer[:name]}>"
#           @result << "    a :Layer, dcat:Dataset ;"
#           @result << "    rdfs:label #{layer[:name].to_json} ;"
#           @result << "    dc:title #{layer[:title].to_json} ;" if layer[:title]
#           @result << "    dc:description #{layer[:description].to_json} ;" if layer[:description]
#           @result << "    geos:hasGeometry #{layer[:wkt].round_coordinates(Serializers::COORDINATE_PRECISION).to_json} ;" if layer[:wkt]
#           @result << "    dcat:contactPoint ["
#           @result << "        a foaf:Person ;"
#           @result << "        foaf:name #{layer[:owner][:name].to_json} ;"
#
#           # All properties of layer:
#           # - category_id
#           # - subcategory
#           # - licence
#           # - authoritative
#           # - rdf_type
#           # - data_sources
#           # - @context
#           # - update_rate
#           # - webservice_url
#           # - sample_url
#           # - imported_at
#           # - created_at
#
#           if layer[:owner][:organization]
#             @result << "        foaf:mbox #{layer[:owner][:email].to_json} ;"
#             @result << "        org:memberOf ["
#             @result << "            a foaf:Organization ;"
#             @result << "            foaf:name #{layer[:owner][:organization].to_json} ;"
#             @result << "            foaf:homepage #{layer[:owner][:website].to_json} ;" if layer[:owner][:website]
#             @result << "        ] ."
#           else
#             @result << "        foaf:mbox #{layer[:owner][:email].to_json} ."
#           end
#
#           @result << "    ] ."
#
#           first = false
#         end
#       end
#
#       def endpoints
#       end
#
#     end
#   end
# end
