# CitySDK LD API website

Website for [CitySDK Linked Data API](https://github.com/waagsociety/citysdk-ld).

Endpoint-specific configuration is in [`data/_endpoint.yml`](../../blob/gh-pages/_data/endpoint.yml). This YAML file is [used by Jekyll](http://jekyllrb.com/docs/datafiles/) for the endpoint URL, location and data examples.

[GitHub Pages](https://pages.github.com/) will automatically serve the CitySDK LD API site - it is a Jekyll website in the `gh-pages` branch. When forked, the website will be hosted at _http://**username**.github.io/citysdk-ld_.

## Build and deploy

First, install [Jekyll](http://jekyllrb.com/).

    git clone https://github.com/waagsociety/citysdk-ld.git
    cd citysdk-ld
    git fetch origin gh-pages
    git checkout gh-pages
    jekyll build --config _config.yml,_config_deploy_root.yml

The site is built inside the `_site` directory, and can either be served from there, or copied to your web server's directory.

## Run locally

To use Jekyll's built-in web server to run and test the website locally, run the following command:

```bash
jekyll serve --watch --baseurl ''
```

The website will be available at [http://localhost:4000/](http://localhost:4000/).

##

## jekyll-hook

If you wish to use your own server to deploy the CitySDK LD API website, you can use [jekyll-hook](https://github.com/developmentseed/jekyll-hook) to listen to [GitHub webhooks](https://developer.github.com/webhooks/). Every time a file changes in your repository, GitHub will connect to jekyll-hook running on your server, and you can pull, compile and deploy the newest version of the website.
