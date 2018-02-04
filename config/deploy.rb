require "rvm/capistrano"
require "bundler/capistrano"
require 'capistrano/ext/multistage'
require "whenever/capistrano"
require 'capistrano/sidekiq'


# As a work around for error: Host key verification failed.
ssh_options[:forward_agent] = true
default_run_options[:pty] = true

set :stages, %w(production staging)
set :default_stage, "staging"
set :default_shell, '/bin/bash -l'
set :whenever_command, "bundle exec whenever"

set :scm, "git"
set :branch, "master"
set :repository,  "ssh://git@github.com/christiePaz/dote-web.git"
set :deploy_via,  :remote_cache
set :keep_releases, 4

# Deploy Tasks
namespace :deploy do
  # Passenger Restart
  namespace :passenger do
    desc "Restart Application"
    task :restart, :roles => :app do
      run "cd #{current_path}; touch tmp/restart.txt"
    end
    desc "Stop Passenger"
      task :stop, :roles => :app do
      run "touch #{current_path}/tmp/stop.txt"
    end
  end

  # Server Settings
  desc "Use custom (domain specific) database.yml"
  task :copy_custom_files, :roles => :app do
    run "cd #{current_path}; if [ -d config/deploy/#{application}-#{branch} ] ; then cp -a config/deploy/#{application}-#{branch}/* ./; fi; "
  end

  desc "Custom restart task"
  task :restart, :roles => :app, :except => { :no_release => true } do
    deploy.passenger.restart
  end
end


# Callbacks
after "deploy", "deploy:migrate"
after "deploy:update", "deploy:copy_custom_files"
after "deploy:update", "deploy:cleanup"
# after 'deploy:finishing', "sidekiq:restart"
after 'deploy:starting', 'sidekiq:quiet'
after 'deploy:updated', 'sidekiq:stop'
after 'deploy:reverted', 'sidekiq:stop'
after 'deploy:published', 'sidekiq:start'
