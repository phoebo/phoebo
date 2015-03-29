module Phoebo
  class Application < Rails::Application
    attr_accessor :setup_thread

    # Start setup job after application initalization
    config.after_initialize do |app|
      if defined?(Rails::Server)
        app.reload_routes!
        webhook_url = app.routes.url_helpers.webhook_url

        app.setup_thread = Thread.new do |t|
          SetupJob.new.perform(webhook_url)
        end
      end
    end

    def setup_completed?
      setup_thread && !setup_thread.alive? && setup_thread.value == SetupJob::STATE_DONE
    end
  end
end