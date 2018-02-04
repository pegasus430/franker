Airbrake.configure do |config|
  config.api_key = '9704b834f87772f5ad165e0dd4593580'
  config.host    = 'errbit.doteshopping.com'
  config.port    = 80
  config.secure  = config.port == 443
end