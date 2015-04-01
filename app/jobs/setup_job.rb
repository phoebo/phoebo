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
    @singularity = SingularityConnector.new

    # Find orphaned tasks
    existing_task_ids = Task.existing.pluck(:id)
    orphaned_task_ids = { ours: existing_task_ids.dup, singularity: [] }

    @singularity.requests.each do |data|
      ids = @singularity.parse_request_id(data[:request][:id]) rescue nil
      next unless ids
      task_id = ids[:task_id]

      unless (index = orphaned_task_ids[:ours].find_index(task_id)).nil?
        orphaned_task_ids[:ours].delete_at(index)
      else
        orphaned_task_ids[:singularity] << [ task_id, data[:request][:id] ]
      end
    end

    # Mark tasks orphaned by Singularity without our knowledge
    Task.where(id: orphaned_task_ids[:ours]).update_all(state: Task.states[:deleted])

    # Delete task requests orphaned by us
    orphaned_task_ids[:singularity].each do |task_id|
      delete_task(task_id.first, task_id.second)
    end

    # Install Singularity webhooks
    @singularity.install_webhook('phoebo-request', urls[:request_webhook], :REQUEST)
    @singularity.install_webhook('phoebo-task', urls[:task_webhook], :TASK)
    @singularity.install_webhook('phoebo-deploy', urls[:deploy_webhook], :DEPLOY)

    # Deploy Logspout service if not deployed
    create_logspout_task(urls[:logspout])
  end

  def delete_task(task_id, request_id)
    Task.where(id: task_id).update_all(state: Task.states[:deleting])
    @singularity.remove_request(request_id)
  end

  def create_logspout_task(url)
    task = Task.where(build_request_id: -1, state: Task.states[:running]).first

    # Note: There is a bug in Singularity 4.1 which ignores BRIDGE networking unless
    #  portMappings are specified.
    #
    # Logspout listens on this port and offers streaming channels for debugging.
    # This port SHOULD NOT be made publicly available!
    deploy_template = {
      arguments: [ url ],
      containerInfo: {
        volumes: [
          { hostPath: '/var/run/docker.sock', containerPath: '/tmp/docker.sock', mode: 'RW' }
        ],
        docker: {
          network: 'BRIDGE',
          image: 'phoebo/logspout:latest',
          portMappings: [
            {
              containerPortType: 'LITERAL',
              containerPort: 3000,
              hostPortType: 'FROM_OFFER',
              hostPort: 0,
              protocol: 'tcp'
            }
          ]
        }
      },
      resources: {
        numPorts: 1
      }
    }

    # Check if existing task matches our deploy template
    if task
      unless task.deploy_template.deep_diff(deploy_template).empty?
        delete_task(task.id, task.request_id)
        task = Task.new
      end
    else
      task = Task.new
    end

    # Do we need to create a new task?
    unless task.persisted?
      task.build_request_id = -1
      task.deploy_template = deploy_template
      task.save
    end

    Rails.logger.info "Starting logspout task #{task.id}"
    ScheduleJob.perform_now(task)
  end
end
