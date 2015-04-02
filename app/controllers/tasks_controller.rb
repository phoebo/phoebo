class TasksController < ApplicationController
  include Tubesock::Hijack

  before_filter :authenticate_user!

  def index
    js url: watch_tasks_path
  end

  def show
    @task = Task.find(params[:id])
    js url: watch_task_path
  end

  def watch
    options = { }
    options[:projects] = current_user.gitlab.cached_user_projects

    if params[:id]
      begin
        options[:task] = Task.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        head :not_found
        return
      end
    end

    hijack do |tubesock|
      # Create new client thread
      client_thread = Thread.new do
        UpdateStream.new(tubesock, options).run
      end

      # Kill the thread when connection is closed
      tubesock.onclose do
        client_thread.kill
      end
    end

    head :ok
  end

  # ----------------------------------------------------------------------------

  class UpdateStream
    attr_reader :tubesock, :task_id

    def self.build_notification_payload(project_info, task)
      data = { }
      if task.build_request && project_info
        data[:build] = {
          id: task.build_request.id,
          name: [ project_info[:namespace][:name], project_info[:name] ],
          ref: task.build_request.ref
        }
      end

      data[:service] = true if task.service?

      if task.mesos_id
        data[:mesos] = task.mesos_info || { }
        data[:mesos][:task_id] = task.mesos_id
      end

      data[:state]         = task.state
      data[:state_message] = task.state_message unless task.state_message.empty?
      data
    end

    def initialize(tubesock, options = {})
      @tubesock  = tubesock
      @task     = options[:task]
      @projects = options[:projects]
      @subscribe_to_log = @task ? true : false

      @subscription_handlers = []

      @task_info = Hash.new do |hash, key|
        hash[key] = {
          state:       -1,
        }
      end

      @log_info = Hash.new do |hash, key|
        hash[key] = {
          task_id: nil,
          counter: -1
        }
      end
    end

    # Send message
    def send_data(task_id, data)
      if task_id
        payload = {}
        payload[task_id] = data
      else
        payload = data
      end

      if @tubesock
        @tubesock.send_data(payload.to_json)
      else
        puts payload.inspect
      end
    end

    # Send state change
    def set_task_state(task_id, new_state, data)
      if @task_info[task_id][:state] < 0 || Task.valid_next_state?(@task_info[task_id][:state], Task.states[new_state])
        @task_info[task_id][:state] = Task.states[new_state]
        send_data(task_id, data)
      end
    end

    # Subscribe for log updates and load previous log output
    def set_task_mesos_id(task_id, mesos_id)
      if @log_info[mesos_id][:task_id].nil?
        @log_info[mesos_id][:task_id] = task_id

        if @subscribe_to_log
          log_key = Redis.key_for_mesos_log(mesos_id)
          log_updates_key = Redis.key_for_mesos_log_updates(mesos_id)

          # Subscribe to log updates
          subscribe_channel(log_updates_key) do
            log = nil

            with_redis do |redis|
              # We need new connection to redis, because we can't read while subscribed
              redis2 = redis.dup
              log = redis2.lrange(log_key, 0, -1)
              redis2.disconnect!
            end

            log.reverse_each do |log_entry|
              process_log(mesos_id, JSON.parse(log_entry, symbolize_names: true))
            end
          end
        end
      end
    end

    # Process log and check continuity
    def process_log(mesos_task_id, data)
      log_counter =  data[:counter].to_i
      diff = @log_info[mesos_task_id][:counter] - log_counter
      if diff < 0 || diff > 200
          @log_info[mesos_task_id][:counter] = log_counter
          send_data(@log_info[mesos_task_id][:task_id], log: data[:data])
      end
    end

    # Process initial state
    def send_initial_state
      process_task = Proc.new do |task|
        @task_info[task.id][:state] = Task.states[task.state]

        send_data(task.id, self.class.build_notification_payload(
          task.build_request ? @projects[task.build_request.project_id] : nil,
          task
        ))

        set_task_mesos_id(task.id, task.mesos_id) unless task.mesos_id.empty?
      end

      if @task
        # We have to reload it
        task = Task.find_by(id: @task.id)
        process_task.call(task)
      else
        tasks = Task.joins('LEFT OUTER JOIN build_requests ON tasks.build_request_id = build_requests.id')
          .where('tasks.state <> ?', Task.states[:deleted])
          .where('(build_requests.id IS NULL OR build_requests.project_id IN (?))', @projects.keys)

        tasks.each(&process_task)
      end

      send_data(nil, :subscribed)
    end

    def process_message(channel, message)
      data = JSON.parse(message, symbolize_names: true)

      # project/*/build_request/*/task/*/updates
      if ids = Redis.parse_key_for_task_updates(channel)
        set_task_state(ids[:task_id], data[:state], data) unless data[:state].nil?
        set_task_mesos_id(ids[:task_id], data[:mesos_id]) unless data[:mesos_id].nil?

      # logs
      elsif mesos_task_id = Redis.parse_key_for_mesos_log_updates(channel)
        process_log(mesos_task_id, data) unless data[:counter].nil?
      end

      return true
    rescue JSON::ParserError
      return false
    end

    def run
      if @task
        subscribe_channel(@task.updates_channel) do
          send_initial_state
        end
      else
        # Collect all project channel patterns
        channels = @projects.keys.collect do |project_id|
          Redis.composite_key('project', project_id, '*')
        end

        # Non-project tasks
        channels << Redis.composite_key('project', '-', '*')

        psubscribe_channel(*channels) do
          send_initial_state
        end
      end
    end

    # --------------------------------------------------------------------------

    # Subscribes to channel/s and yields block once all channels are subcribed
    def subscribe_channel(*channels, &block)
      subscribe_helper(:subscribe, channels, &block)
    end

    # Subscribes to pattern channel/s and yields block once all channels are subcribed
    def psubscribe_channel(*channels, &block)
      subscribe_helper(:psubscribe, channels, &block)
    end

    # Subscription helper for Redis.psubscribe and Redis.subscribe calls
    def subscribe_helper(method, channels, &block)
      if block_given?
        @subscription_handlers << [ channels, block ]
      end

      with_redis do |redis|
        if redis.subscribed?
          redis.send(method, *channels)
        else
          redis.send(method, *channels, &method(:subscription_block))
        end
      end
    end

    # Unified block for Redis.psubscribe and Redis.subscribe calls
    # Registers message handler to .process_message and calls block
    # once all channels are subscribed
    def subscription_block(on)
      on_subscription = Proc.new do |channel, num_subscriptions|
        @subscription_handlers.each.with_index do |pair, index|
          if pair.first.delete(channel)
            if pair.first.empty?
              @subscription_handlers.delete_at(index)

              pair.second.call
            end

            break
          end
        end
      end

      on.subscribe(&on_subscription)
      on.psubscribe(&on_subscription)
      on.message(&method(:process_message))
      on.pmessage do |_, channel, message|
        process_message(channel, message)
      end
    end
  end
end
