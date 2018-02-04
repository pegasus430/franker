Airbrake.configure do |config|
  config.api_key = '8e7be2d1b9150c88079f82e05bb3e0aa'
  config.host    = 'errbit.doteshopping.com'
  config.port    = 80
  config.secure  = config.port == 443
end