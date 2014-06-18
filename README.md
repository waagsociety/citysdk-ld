# CitySDK LD API v1.0

Working branch for CitySDK LD API v1.0.

Files and directories were copied from master branch (v0.9), and need moving/renaming/rewriting/refactoring!

    CREATE EXTENSION postgis;
    CREATE EXTENSION hstore;
    CREATE EXTENSION pg_trgm;

## RuboCop

We use [RuboCop](https://github.com/bbatsov/rubocop) to analyze the API's Ruby code. To start code analysis, run `rubocop`. RuboCop's settings are in [`.rubocop.yml`](https://github.com/waagsociety/citysdk-ld/blob/master/.rubocop.yml). See [`enabled.yml`](https://github.com/bbatsov/rubocop/blob/master/config/enabled.yml) in the RuboCop repository for the full list of options.