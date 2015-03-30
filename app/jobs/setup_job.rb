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

  def setup(urls)
    singularity = SingularityConnector.new

    # Find orphaned tasks
    existing_task_ids = Task.existing.pluck(:id)
    orphaned_task_ids = { ours: existing_task_ids.dup, singularity: [] }

    singularity.requests.each do |data|
      task_id = Task.parse_request_id(data[:request][:id]) rescue nil
      next unless task_id

      unless (index = orphaned_task_ids[:ours].find_index(task_id)).nil?
        orphaned_task_ids[:ours].delete_at(index)
      else
        orphaned_task_ids[:singularity] << task_id
      end
    end

    # Mark tasks orphaned by Singularity without our knowledge
    Task.where(id: orphaned_task_ids[:ours]).update_all(state: Task.states[:deleted])

    # Delete task requests orphaned by us
    orphaned_task_ids[:singularity].each do |task_id|
      singularity.remove_request(Task.request_id(task_id))
    end

    # Install Singularity webhooks
    singularity.install_webhook('phoebo-request', urls[:request_webhook], :REQUEST)
    singularity.install_webhook('phoebo-task', urls[:task_webhook], :TASK)
    singularity.install_webhook('phoebo-deploy', urls[:deploy_webhook], :DEPLOY)
  end
end
