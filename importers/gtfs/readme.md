###CitySDK gtfs importer

Imports or updates a set of gtfs feeds to postgres.
Adds utility functions to database.

(In NL download gtfs comes from http://gtfs.ovapi.nl)

* import_gtfs.rb 

Can be used to import or update a single, locally stored feed. 
Reads database info from the locally running citysdk api, the local dev directory or the command line. 

    usage: import_gtfs [-p prefix] <gtfs directory>
           Imports or updates gtfs database from gtfs directory
      options:
           -p, --prefix:   prefix to add to id's that need to be unique.

* gtfs_funcs.rb
* gtfs_util.rb

Used by the importer.

* clear.rb

Clears all gtfs info from the database.


* update_feeds

Designed to run periodically and check feeds online.
Updates local database when new versions are available.

* feed_dlds.yaml

Is created by update_feeds, keeps track of updates.
Can be edited to add feeds. 
When not found, a default set is written from the update_feeds script.
Edit the update_feeds.rb script to store the feeds to your citysdk endpoint permanently (and delete the yaml file).


* kv8daemon

Daemon to link to the Dutch real-time public transport feed; will not work elsewhere, but may be useful as an example of a possible way to deal with high-throughput realtime information.




