class SingularityWorker
  include Sidekiq::Worker

  class Helpers
    def initialize(worker)
      @worker = worker
    end

    def config
    	Rails.configuration.singularity
    end
  end
end