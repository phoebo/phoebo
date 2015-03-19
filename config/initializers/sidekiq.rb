Sidekiq.configure_server do |config|
  config.redis = { url: 'redis://' + Rails.configuration.redis.host + ':6379' }
end

Sidekiq.configure_client do |config|
  config.redis = { url: 'redis://' + Rails.configuration.redis.host + ':6379' }
end