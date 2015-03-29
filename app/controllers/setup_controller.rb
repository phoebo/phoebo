class SetupController < ApplicationController
  include Tubesock::Hijack

  before_filter :authenticate_user!
  skip_filter :check_setup

  def index
    if Rails.application.setup_completed?
      redirect_to root_path
      return
    end

    js url: watch_setup_path
  end

  def watch
    hijack do |tubesock|
      # Create new client thread
      client_thread = Thread.new do
        UpdateStream.new(tubesock).run
      end

      # Kill the thread when connection is closed
      tubesock.onclose do
        client_thread.kill
      end
    end
  end

  # ----------------------------------------------------------------------------
  class UpdateStream
    def initialize(tubesock)
      @tubesock  = tubesock
      @state = -1
    end

    def run
      with_redis do |redis|
        redis.subscribe(SetupJob::REDIS_KEY_UPDATES) do |on|
          # Subscribed -> Send initial data
          on.subscribe do
            # We need another connection because redis does not allow you
            # to use it while subscribed
            redis2 = redis.dup
            message = redis2.get(SetupJob::REDIS_KEY_STATE)
            redis2.disconnect!

            process_message(message) if message
          end

          on.message do |_, message|
            process_message(message)
          end
        end
      end
    end

    # Process message
    def process_message(message)
      data = JSON.parse(message, symbolize_names: true)
      new_state = data[:state].to_i

      if @state < new_state
        @state = new_state
        @tubesock.send_data(message)
      end
    end
  end
end
