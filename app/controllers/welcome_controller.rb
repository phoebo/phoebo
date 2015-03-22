class WelcomeController < ApplicationController
  include Tubesock::Hijack

  def initialize
    @current_task_id = 'test-task10'
    super
  end

  def index
    # render plain: "ok"
  end

  def run
    # TODO: we should add some security token
    # webhook_url = url_for controller: 'singularity', action: 'webhook'
    webhook_url = 'http://10.10.3.230:3000/webhook'

    begin
      task = Task.create(id: @current_task_id)
      # TaskSchedulerJob.perform_later task, webhook_url
      TaskSchedulerJob.perform_now task, webhook_url

    rescue ActiveRecord::RecordNotUnique
      # TODO: show some error
    end

    redirect_to action: 'index'
  end

  def restart
    task_id = @current_task_id
    Task.delete(task_id)

    task_key = Redis.composite_key('task', task_id, 'mesos-id')
    with_redis do |redis|
      redis.del(task_key)
    end

    redirect_to action: 'run'
  end

  def update_stream
    hijack do |tubesock|

      # Create new client thread
      client_thread = Thread.new do
        UpdateStream.new(tubesock, @current_task_id).run
      end

      # Kill the thread when connection is closed
      tubesock.onclose do
        client_thread.kill
      end
    end
  end

  class UpdateStream
    attr_reader :tubesock, :task_id

    def initialize(tubesock, task_id)
      @tubesock = tubesock
      @task_id = task_id

      # We need exclusive Redis connection for our thread (can't be shared)
      @redis = Redis.new(host: Rails.configuration.redis.host)
    end

    # Send message
    def send_data(data)
      @tubesock.send_data(data)
    end

    # Send state change
    def task_state=(new_state)
      if @task_state.nil? || Task.states[@task_state] < Task.states[new_state]
        @task_state = new_state
        send_data(state: new_state)
      end
    end

    # Subscribe for log updates and load previous log output
    def task_mesos_id=(mesos_id)
      if @task_mesos_id.nil?
        @task_mesos_id = mesos_id

        log_key = Redis.composite_key('mesos-task', mesos_id, 'log')
        log_updates_key = Redis.composite_key('mesos-task', mesos_id, 'log-updates')

        # Subscribe for log updates
        @redis.subscribe log_updates_key

        # We need new connection to redis, because we can't read while subscribed
        redis = Redis.new(host: Rails.configuration.redis.host)
        redis.lrange(log_key, 0, -1).reverse_each do |log_entry|
          process_log(JSON.parse(log_entry, symbolize_names: true))
        end

        redis.disconnect!
      end
    end

    def run
      updates_key = Redis.composite_key('task', @task_id, 'updates')
      initialized = false

      # Send data whenever something is published
      @redis.subscribe updates_key do |on|
        on.subscribe do |channel, subscriptions|
          unless initialized
            initialized = true
            process_initial_state
          end
        end

        on.message do |channel, message|
          data = JSON.parse(message, symbolize_names: true)
          process_message(data)
        end
      end
    end

    # Process initial state
    def process_initial_state
      task = Task.find_by(id: @task_id)
      self.task_state = task.state
      self.task_mesos_id = task.mesos_id unless task.mesos_id.empty?
    end

    # Process recieved update
    def process_message(data)
      self.task_state = data[:state] unless data[:state].nil?
      self.task_mesos_id = data[:mesos_id] unless data[:mesos_id].nil?
      self.process_log(data) unless data[:counter].nil?
    end

    # Process log and check continuity
    def process_log(data)
      if @log_counter.nil?
        @log_counter = data[:counter].to_i
        send_data(log: data[:data])
      else
        diff = @log_counter - data[:counter].to_i
        if diff < 0 || diff > 200
          @log_counter = data[:counter]
          send_data(log: data[:data])
        end
      end
    end
  end
end
