set :application, "dote-web"
set :rails_env, "production"

# set :branch, "v4-0"
set :branch, "scraping"

set :user, "deploy"
set :password, "d3pl0y.at"
set :runner, user
set :use_sudo, false
set :whenever_environment, 'production'

set :servers, "54.68.28.109"    # apiscraping
# set :servers, "54.68.154.242"     # apiscraping-1

set :deploy_to, "/var/www/apps/#{application}"

role :app, servers
role :web, servers
role :db, servers, :primary => true