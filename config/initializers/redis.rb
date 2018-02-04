$redis = Redis::Namespace.new("dote_prod", redis: Redis.new(host: "localhost", port: 6379, db: 1)) if Rails.env.production?
$redis = Redis::Namespace.new("dote_staging", redis: Redis.new(host: "localhost", port: 6379, db: 1)) if Rails.env.staging?
$redis = Redis::Namespace.new("dote_dev", redis: Redis.new(host: "localhost", port: 6379, db: 0)) if Rails.env.development?