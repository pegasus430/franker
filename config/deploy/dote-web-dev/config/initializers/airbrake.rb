Airbrake.configure do |config|
  config.api_key = '2415caf23624fb80441174c863a691b8'
  config.host    = 'errbit.doteshopping.com'
  config.port    = 80
  config.secure  = config.port == 443
end