module Phoebo
  class Application < Rails::Application
    attr_accessor :setup_thread

    # Start setup job after application initalization
    config.after_initialize do |app|
      if defined?(Rails::Server)
        app.reload_routes!

        # TODO: save secret for later check
        secret = SecureRandom.hex
        url_helpers = app.routes.url_helpers

        urls = {
          request_webhook: url_helpers.singularity_request_webhook_url(secret),
          task_webhook:    url_helpers.singularity_task_webhook_url(secret),
          deploy_webhook:  url_helpers.singularity_deploy_webhook_url(secret)
        }

        app.setup_thread = Thread.new do |t|
          SetupJob.new.perform(urls)
        end
      end
    end

    def setup_completed?
      setup_thread && !setup_thread.alive? && setup_thread.value == SetupJob::STATE_DONE
    end
  end
end