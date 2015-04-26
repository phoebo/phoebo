class Redis
  class << self
    def composite_key(*args)
      args.collect do |arg|
        arg.to_s.gsub(/\\/, '\\\\\\\\').gsub(/\//, '\\\\/')
      end.join('/')
    end
  end
end

# Use Sidekiq connection pool
def with_redis(&block)
  Sidekiq.redis(&block)
end