class WelcomeController < ApplicationController
  include Tubesock::Hijack

  def index
    # render plain: url
    # redis.del('log')
  end

  def run
    # TODO: we should add some security token
    # webhook_url = url_for controller: 'singularity', action: 'webhook'
    webhook_url = 'http://10.10.3.230:3000/webhook'

    begin
      task = Task.create(id: 'test-task')
      TaskSchedulerJob.perform_later task, webhook_url

    rescue ActiveRecord::RecordNotUnique
      # TODO: show some error
    end

    redirect_to action: 'index'
  end

  def update_stream
    hijack do |tubesock|
      tubesock.onopen do

        # Task
        task_id = 'test-task'

        # Initial data
        initial_task = nil
        initial_data = nil

        # We need a semaphore for synchronization of initial data with
        # data recieved with subscribe
        semaphore = Mutex.new
        semaphore.lock

        # Subscribe within its own thread
        redis_thread = Thread.new do

          # Create new Redis connection for our thread (can't be shared)
          redis = Redis.new(host: Rails.configuration.redis.host)

          # Send data whenever something is published
          redis.subscribe "task-#{task_id}" do |on|
            on.message do |channel, message|
              if semaphore
                semaphore.lock     # Wait until data are loaded
                semaphore.unlock   # Unlock and destroy semaphore once we succeeded
                semaphore = nil    # (we need it only for the send of initial data)

                # TODO: test if message was not contained in initial data
                if true
                  tubesock.send_data message
                end
              else
                tubesock.send_data message
              end
            end
          end
        end

        # Send current task state
        initial_task = Task.find_by(id: task_id)
        tubesock.send_data({ state: initial_task.state }.to_json)

        # Send current task log
        # initial_data = redis.get('log')
        tubesock.send_data initial_data unless initial_data.nil?

        # Let the subscription thread proceeed
        semaphore.unlock

        # Kill the thread when connection is closed
        tubesock.onclose do
          redis_thread.kill
        end
      end
    end
  end
end
