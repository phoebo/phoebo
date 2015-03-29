module Phoebo
  class Application < Rails::Application
    attr_accessor :setup_thread

    # Start setup job after application initalization
    config.after_initialize do |app|
      webhook_url = 'url'

      app.setup_thread = Thread.new do |t|
        abort_on_exception = true
        SetupJob.new.perform(webhook_url)
      end
    end

    def setup_completed?
      !setup_thread.alive? && setup_thread.value == SetupJob::STATE_DONE
    end
  end
end