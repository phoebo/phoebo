class SetupJob < ActiveJob::Base
  queue_as :default

  # Redis keys
  REDIS_KEY_UPDATES = Redis.composite_key('setup', 'updates')
  REDIS_KEY_STATE   = Redis.composite_key('setup', 'state')
  REDIS_KEY_MESSAGE = Redis.composite_key('setup', 'message')

  # Setup states
  STATE_AWAITING = 0
  STATE_WORKING  = 1
  STATE_DONE     = 2
  STATE_FAILED   = 3

  def perform(*args)
    update_state(STATE_WORKING, nil)
    setup(*args)
    update_state(STATE_DONE)
  rescue => e
    update_state(STATE_FAILED, e.message)
  end

  private

  # Sends updated state to redis
  def update_state(state, *args)
    with_redis do |redis|
      redis.multi do
        unless args.empty?
          if args.first.nil?
            redis.del(REDIS_KEY_MESSAGE)
          else
            redis.set(REDIS_KEY_MESSAGE, args.first)
          end
        end

        redis.set(REDIS_KEY_STATE, state)
        redis.publish(REDIS_KEY_UPDATES, state)
      end
    end
  end

  # ----------------------------------------------------------------------------

  def setup(webhook_url)
    puts "Do something"
  end
end
