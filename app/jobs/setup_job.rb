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

    # Initialize Broker with Singularity tasks
    Rails.application.broker = Broker.new(fetch_tasks)

    # Install Singularity webhooks
    @singularity.install_webhook('phoebo-request', urls[:request_webhook], :REQUEST)
    @singularity.install_webhook('phoebo-task', urls[:task_webhook], :TASK)
    @singularity.install_webhook('phoebo-deploy', urls[:deploy_webhook], :DEPLOY)

    # Kill all logspout tasks
    @logspout_request_ids.each do |request_id|
      @singularity.remove_request(request_id)
    end

    # Deploy Logspout service if not deployed
    create_logspout_task(urls[:logspout])
  end

  def fetch_tasks
    tasks = []
    @logspout_request_ids = []

    @singularity.requests.each do |request_info|
      request_id = request_info[:request][:id]
      next unless request_id =~ /^phoebo-/

      if request_info[:state] == 'ACTIVE' && request_info[:requestDeployState] && request_info[:requestDeployState][:activeDeploy]
        task = Broker::Task.new

        # Get task info
        task.request_id = request_id
        task.daemon = request_info[:request][:daemon] ? true : false

        # Get deploy info
        deploy_info = @singularity.request_deploy(request_id, request_info[:requestDeployState][:activeDeploy][:deployId])
        if deploy_info[:deploy][:metadata]
          deploy_info[:deploy][:metadata].each do |k, v|
            if m = k.to_s.match(/^phoebo_(.+)$/)
              if task.respond_to?(sym = "#{m[1]}=".to_sym)
                task.send(sym, v)
              end
            end
          end
        end

        if request_id =~ /-logspout$/
          task.name += ' (OLD)'
          @logspout_request_ids << request_id
        end

        # Apply for each instance
        if !(task_info = @singularity.request_tasks(request_id, true)).empty?
          task_info.each do |item|
            task2 = task.dup
            task2.state = tr_task_state(item[:lastTaskState])
            task2.run_id = item[:taskId][:id]
            tasks << task2
          end
        elsif !(task_info = @singularity.request_tasks(request_id)).empty?
          item = task_info.max_by { |item| item[:updatedAt] }
          task.state = tr_task_state(item[:lastTaskState])
          task.run_id = item[:taskId][:id]
          tasks << task
        else
          task.state = :fresh
          tasks << task
        end
      end
    end

    tasks
  end

  def create_logspout_task(url)
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
      },
      metadata: {
        phoebo_name: 'Logspout'
      }
    }

    request_id = 'logspout'
    request_info = @singularity.create_request('logspout', true)

    Rails.application.broker.new_task do |task|
      task.state = Broker::Task::STATE_REQUESTED
      task.name = 'Logspout'
      task.request_id = request_info[:request][:id]
      task.daemon = true
    end

    @singularity.create_deploy(request_info, deploy_template)
  end

  def tr_task_state(state)
    case state
    when 'TASK_LAUNCHED'
      state = :launched
    when 'TASK_RUNNING'
      state = :running
    when 'TASK_FINISHED'
      state = :finished
    when 'TASK_FAILED', 'TASK_KILLED', 'TASK_LOST'
      state = :failed
    else
      :fresh
    end
  end
end
