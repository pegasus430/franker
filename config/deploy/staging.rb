set :application, "dote-web"
set :rails_env, "staging"

set :branch, "dev"

set :user, "deploy"
set :password, "d3pl0y.at"
set :runner, user
set :use_sudo, false
set :whenever_environment, 'staging'

# set :servers, "ec2-54-191-61-198.us-west-2.compute.amazonaws.com"
# set :servers, "54.201.34.115" - Old Dev Server 3.5 GB ram
set :servers, "52.10.228.16"

set :deploy_to, "/var/www/apps/#{application}"

role :app, servers
role :web, servers
role :db, servers, :primary => true