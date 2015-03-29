class SetupJob

  # Redis keys
  REDIS_KEY_UPDATES = Redis.composite_key('setup', 'updates')
  REDIS_KEY_STATE   = Redis.composite_key('setup', 'state')

  # Setup states
  STATE_AWAITING = 0
  STATE_WORKING  = 1
  STATE_DONE     = 2
  STATE_FAILED   = 3

  def perform(*args)
    update_state(STATE_WORKING)
    setup(*args)
    update_state(STATE_DONE)
  rescue => e
    update_state(STATE_FAILED, e.message)
  end

  private

  # Sends updated state to redis
  def update_state(state, message = nil)
    data = { state: state }
    data[:state_message] = message unless message.nil?
    payload = data.to_json

    with_redis do |redis|
      redis.multi do
        redis.set(REDIS_KEY_STATE, payload)
        redis.publish(REDIS_KEY_UPDATES, payload)
      end
    end

    state
  end

  # ----------------------------------------------------------------------------

  def setup(webhook_url)
    singularity = SingularityConnector.new
    singularity.install_webhook(webhook_url)
  end
end
