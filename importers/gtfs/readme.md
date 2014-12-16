#GTFS importer

The GTFS importer adds one of more GTFS feeds to the database.
If there's only one feed to add, do a *reset*, then an *import*.

When there's multiple feeds to import, do the *reset* once, then multiple *imports*.<br/>
Updating feeds is not supported.


##configuration:
The importer expects a file, config.production.json, at '/var/www/citysdk/current/'.<br/>
When your server config is different, adjust the path in line 16 of gtfs_util.rb


    reset:  ruby ./gtfs_reset.rb
    import: ruby ./gtfs_import.rb /path_to_gtfs_dir

