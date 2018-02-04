DoteWeb::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb.
  Braintree::Configuration.environment = :sandbox
  Braintree::Configuration.merchant_id = 'k8b7x9scj5s5gsm3'
  Braintree::Configuration.public_key = 'ktd85c49kdnjrg4g'
  Braintree::Configuration.private_key = '95019622e372afafe64217dedfe81706'
  
  # Braintree::Configuration.environment = :production
  # Braintree::Configuration.merchant_id = '2z46bf8nv8yf8dzz'
  # Braintree::Configuration.public_key = 'gprdk3g3d4ghxxgq'
  # Braintree::Configuration.private_key = 'edfaf282e26bae2c5585c396a66e3504'
  
  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations
  config.active_record.migration_error = :page_load

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = true

  # config.action_mailer.default_url_options = { :host => 'localhost:3000' }
  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.perform_deliveries = true
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
  address:              'smtp.gmail.com',
  port:                 587,
  domain:               'usedote.com',
  user_name:            'hello@usedote.com',
  password:             '7cinder7',
  authentication:       'plain',
  enable_starttls_auto: true  }

  config.after_initialize do
    Bullet.enable = true
    Bullet.alert = true
    Bullet.bullet_logger = true
    Bullet.console = true
    Bullet.rails_logger = true
  end

  # Set to :debug to see everything in the log.
  config.log_level = :debug
end