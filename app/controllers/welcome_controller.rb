class WelcomeController < ApplicationController
  include Tubesock::Hijack

  def index
    # render plain: url
  end

  def run
    redis.append "log", "Scheduled to launch\n"
    redis.publish "log", "Scheduled to launch"

    # webhook_url = url_for controller: 'singularity', action: 'webhook'
    webhook_url = 'http://10.10.3.3:3000/webhook'

    # For synchronous testing
    TaskWorker.new.perform(webhook_url)
    # TaskWorker.perform_async()

    redirect_to action: 'index'
  end

  def update_stream
    hijack do |tubesock|
      tubesock.onopen do

        # Initial data
        initial_data = nil

        # We need a semaphore for synchronization of initial data with
        # data recieved with subscribe
        semaphore = Mutex.new
        semaphore.lock

        # Subscribe within its own thread
        redis_thread = Thread.new do

          # Create new Redis connection for our thread (can't be shared)
          redis = Redis.new(host: Rails.configuration.redis.host)

          # Send data whenerever something is published
          redis.subscribe "log" do |on|
            on.message do |channel, message|
              if semaphore
                semaphore.lock     # Wait until data are loaded
                semaphore.unlock   # Unlock and destroy semaphore once we succeeded
                semaphore = nil    # (we need it only for the send of initial data)

                # TODO: test if message was not contained in initial data
                if initial_data
                  tubesock.send_data message
                end
              else
                tubesock.send_data message
              end
            end
          end
        end

        initial_data = redis.get('log')
        tubesock.send_data initial_data
        semaphore.unlock

        # Kill the thread when connection is closed
        tubesock.onclose do
          redis_thread.kill
        end
      end
    end
  end
end
