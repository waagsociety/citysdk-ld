DROP SCHEMA IF EXISTS osm CASCADE;
CREATE SCHEMA osm;

ALTER TABLE planet_osm_line SET SCHEMA osm;
ALTER TABLE planet_osm_nodes SET SCHEMA osm;
ALTER TABLE planet_osm_point SET SCHEMA osm;
ALTER TABLE planet_osm_polygon SET SCHEMA osm;
ALTER TABLE planet_osm_rels SET SCHEMA osm;
ALTER TABLE planet_osm_roads SET SCHEMA osm;
ALTER TABLE planet_osm_ways SET SCHEMA osm;
