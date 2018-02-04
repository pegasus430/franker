require 'sidekiq'

schedule_file = "config/schedule.yml"

if Rails.env.production?
  Sidekiq.configure_client do |config|
    config.redis = { :namespace => 'Dote_Sidekiq', :url => 'redis://127.0.0.1:6379/1' }
  end

  Sidekiq.configure_server do |config|
    config.redis = { :namespace => 'Dote_Sidekiq', :url => 'redis://127.0.0.1:6379/1' }
  end

  Redis.current = ConnectionPool.new(size: 5, timeout: 10000) do
    Redis.new host: "127.0.0.1", port: 6379, db: '1'
  end
elsif Rails.env.staging?
  Sidekiq.configure_client do |config|
    config.redis = { :namespace => 'Dote_Sidekiq', :url => 'redis://127.0.0.1:6379/2' }
  end

  Sidekiq.configure_server do |config|
    config.redis = { :namespace => 'Dote_Sidekiq', :url => 'redis://127.0.0.1:6379/2' }
  end

  Redis.current = ConnectionPool.new(size: 5, timeout: 10000) do
    Redis.new host: "127.0.0.1", port: 6379, db: '2'
  end
else
  Sidekiq.configure_client do |config|
    config.redis = { :namespace => 'Dote_Sidekiq', :url => 'redis://127.0.0.1:6379/0' }
  end

  Sidekiq.configure_server do |config|
    config.redis = { :namespace => 'Dote_Sidekiq', :url => 'redis://127.0.0.1:6379/0' }
  end

  Redis.current = ConnectionPool.new(size: 5, timeout: 10000) do
    Redis.new host: "127.0.0.1", port: 6379, db: '0'
  end
end

if File.exists?(schedule_file)
  Sidekiq::Cron::Job.load_from_hash YAML.load_file(schedule_file)
end
