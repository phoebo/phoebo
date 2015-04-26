if Phoebo.config && !Phoebo.config.errors?
  Sidekiq.configure_server do |config|
    config.redis = { url: 'redis://' + Phoebo.config.redis.host + ':6379' }
  end

  Sidekiq.configure_client do |config|
    config.redis = { url: 'redis://' + Phoebo.config.redis.host + ':6379' }
  end
end