set :stages, %w(civitest production testing)
set :default_stage, 'testing'

require 'capistrano/ext/multistage'

set :application, "citysdk-site"
set :normalize_asset_timestamps, false
# set :repository,  "gits:citysdk"
#
# set :scm, :git

set :repository,  "."
set :scm, :none

set :branch, "master"

set :deploy_to, "/var/www/site.citysdk"
# set :deploy_via, :remote_cache
set :copy_exclude, ['.git', '_site']

set :deploy_via, :copy

set :use_sudo, false
set :user, "citysdk"


namespace :deploy do
  task :start do ; end
  task :stop do ; end
  # Assumes you are using Passenger
  task :restart, :roles => :app, :except => { :no_release => true } do
  end

  task :finalize_update, :except => { :no_release => true } do
    run "rm -rf #{release_path}/config #{release_path}/Capfile"
    #run "cd #{release_path} && jekyll build --config _config.yml,_config_deploy_root.yml"
  end
end


