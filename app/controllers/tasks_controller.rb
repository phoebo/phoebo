class TasksController < ApplicationController
  include Tubesock::Hijack

  def index

  end

  def show
    @task = Task.find(params[:id])
  end

  def watch
    hijack do |tubesock|
      # Create new client thread
      client_thread = Thread.new do
        UpdateStream.new(tubesock, params[:id]).run
      end

      # Kill the thread when connection is closed
      tubesock.onclose do
        client_thread.kill
      end
    end
  end

  def run
    task = Task.find(params[:id])

    webhook_url = 'http://10.10.3.230:3000/webhook'
    # TaskSchedulerJob.perform_later task, webhook_url
    TaskSchedulerJob.perform_now task, webhook_url

    redirect_to task
  end

  def create
    task = Task.create(params.require(:task).permit(:id))

    with_redis do |redis|
      updates_key = Redis.composite_key('task', task.id, 'updates')
      redis.publish updates_key, { state: task.state }.to_json
    end

    redirect_to task
  end

  # ----------------------------------------------------------------------------

  class UpdateStream
    attr_reader :tubesock, :task_id

    def initialize(tubesock, task_id)
      @tubesock  = tubesock
      @task_id   = task_id

      @task_info = Hash.new do |hash, key|
        hash[key] = {
          mesos_id:    nil,
          state:       -1,
          log_counter: -1,
        }
      end

      # We need exclusive Redis connection for our thread (can't be shared)
      @redis = Redis.new(host: Rails.configuration.redis.host)
    end

    # Send message
    def send_data(task_id, data)
      payload = {}
      payload[task_id] = data

      if @tubesock
        @tubesock.send_data(payload.to_json)
      else
        puts payload.inspect
      end
    end

    # Send state change
    def set_task_state(task_id, new_state)
      if @task_info[task_id][:state] < Task.states[new_state]
        @task_info[task_id][:state] = Task.states[new_state]
        send_data(task_id, state: new_state)
      end
    end

    # Subscribe for log updates and load previous log output
    def set_task_mesos_id(task_id, mesos_id)
      if @task_info[task_id][:mesos_id].nil?
        @task_info[task_id][:mesos_id] = mesos_id

        if @task_id
          log_key = Redis.composite_key('mesos-task', mesos_id, 'log')
          log_updates_key = Redis.composite_key('mesos-task', mesos_id, 'log-updates')

          # Subscribe for log updates
          @redis.subscribe log_updates_key

          # We need new connection to redis, because we can't read while subscribed
          redis = Redis.new(host: Rails.configuration.redis.host)
          redis.lrange(log_key, 0, -1).reverse_each do |log_entry|
            process_log(task_id, JSON.parse(log_entry, symbolize_names: true))
          end

          redis.disconnect!
        end
      end
    end

    def run

      # Subscription listener
      initialized = false
      on_subscription = Proc.new do |channel, num_subscriptions|

        # Send initial data if it's the first time
        unless initialized
          initialized = true
          process_initial_state
        end
      end

      # Subscribe for single task
      if @task_id
        updates_key = Redis.composite_key('task', @task_id, 'updates')
        @redis.subscribe updates_key do |on|
          on.subscribe(&on_subscription)
          on.message do |channel, message|
            data = JSON.parse(message, symbolize_names: true)
            process_message(@task_id, data)
          end
        end

      # Subscribe for all updates
      else
        updates_key = Redis.composite_key('task', '*', 'updates')
        channel_rx = /^task\/([^\/]+)\/updates$/

        @redis.psubscribe updates_key do |on|
          on.psubscribe(&on_subscription)
          on.pmessage do |_, channel, message|
            if m = channel_rx.match(channel)
              data = JSON.parse(message, symbolize_names: true)
              process_message(m[1], data)
            end
          end
        end
      end
    end

    # Process initial state
    def process_initial_state
      process_task = Proc.new do |task|
        set_task_state(task.id, task.state)
        set_task_mesos_id(task.id, task.mesos_id) unless task.mesos_id.empty?
      end

      if @task_id
        task = Task.find_by(id: @task_id)
        process_task.call(task)
      else
        all_tasks = Task.all
        all_tasks.each(&process_task)
      end
    end

    # Process recieved update
    def process_message(task_id, data)
      set_task_state(task_id, data[:state]) unless data[:state].nil?
      set_task_mesos_id(task_id, data[:mesos_id]) unless data[:mesos_id].nil?
      process_log(task_id, data) unless data[:counter].nil?
    end

    # Process log and check continuity
    def process_log(task_id, data)
      log_counter =  data[:counter].to_i
      diff = @task_info[task_id][:log_counter] - log_counter
      if diff < 0 || diff > 200
          @task_info[task_id][:log_counter] = log_counter
          send_data(task_id, log: data[:data])
      end
    end
  end
end
