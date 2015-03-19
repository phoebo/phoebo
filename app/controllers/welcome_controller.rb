class WelcomeController < ApplicationController
  include Tubesock::Hijack

  def redis
    @redis ||= Redis.new(host: Rails.configuration.redis.host)
  end

  def index
    # render plain: Rails.configuration.redis.host
  end

  def run
    redis.append "log", "Starting\n"
    redis.publish "log", "Starting"
    SingularityWorker.perform_async('bob', 5)
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
