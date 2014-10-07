# CitySDK LD API v1.0

Working repository for CitySDK LD API v1.0. For more information about the CitySDK LD API, see the [website](http://citysdk.waag.org) or [wiki](wiki).

## Installation

This section describes the installation for development purposes. For installation on a production environment using nginx, see the [wiki](wiki).

Install [PostgreSQL](http://www.postgresql.org/) and [PostGIS](http://postgis.net/), create a database called `citysdk-ld`, and run the following queries:

    CREATE EXTENSION postgis;
    CREATE EXTENSION hstore;
    CREATE EXTENSION pg_trgm;

By default, the API expects access to this new database by using username `postgres` and password `postgres` (but you can edit `config.development.json` to change this).

Install [osm2pgsql](http://wiki.openstreetmap.org/wiki/Osm2pgsql).

Install [Memcached](http://memcached.org/), and make sure it's running.

Clone the CitySDK LD API repository and install all necessary Ruby gems:

    $ git clone https://github.com/waagsociety/citysdk-ld.wiki
    $ cd citysdk-ld
    $ bundle install

Run database migrations - create tables and default data:

    $ ruby db/run_migrations.rb development

Now, you should be able to run the CitySDK API with [Rack](https://github.com/rack/rack):

    $ rackup

The CitySDK LD API should now be running on [localhost:9292](http://localhost:9292/)!

## Data

The API is of little use without data. Let's import some data!

Using the API, it's easy to import any GeoJSON file into the CitySDK LD API. Example scripts and data importers will be available soon, as well as a Ruby gem to make data importing easier.

The CitySDK LD API repository includes two default data importers, one for OpenStreetMap data, and one for GTFS files.

### OpenStreetMap

Download OpenStreetMap file (in this example, we'll use the Amsterdam [OSM Metro Extract](https://mapzen.com/metro-extracts/)):

    $ wget -P ~/Downloads https://s3.amazonaws.com/metro-extracts.mapzen.com/amsterdam_netherlands.osm.pbf

Import the OSM file into the API:

    $ ruby importers/osm/osm_importer.rb -f ~/Downloads/amsterdam_netherlands.osm.pbf

If the script is finished, you can access OSM data via the API: [http://localhost:9292/layers/osm/objects](http://localhost:9292/layers/osm/objects).

### GTFS

Documentation coming soon.

## RuboCop

We use [RuboCop](https://github.com/bbatsov/rubocop) to analyze the API's Ruby code. To start code analysis, run `rubocop`. RuboCop's settings are in [`.rubocop.yml`](https://github.com/waagsociety/citysdk-ld/blob/master/.rubocop.yml). See [`enabled.yml`](https://github.com/bbatsov/rubocop/blob/master/config/enabled.yml) in the RuboCop repository for the full list of options.
