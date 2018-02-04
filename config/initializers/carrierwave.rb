CarrierWave.configure do |config|
  config.fog_directory  = Settings.aws.s3.bucket
  config.fog_public     = true
  if Rails.env == "production" || Rails.env == "staging"
    # config.fog_host = "http://#{Settings.aws.s3.url}"
    config.asset_host = "http://d3e1z3hxo3xobu.cloudfront.net"
  end
  config.fog_credentials = {
    :provider               => 'AWS',                        # required
    :aws_access_key_id      => Settings.aws.s3.access.key_id,
    :aws_secret_access_key  => Settings.aws.s3.access.secret_access_key
  }
end