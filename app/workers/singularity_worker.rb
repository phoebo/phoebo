class SingularityWorker
  include Sidekiq::Worker

  def perform(name, count)
    puts 'Doing hard work'
    Sidekiq.redis do |redis|
      redis.append "log", "Done :)\n"
      redis.publish "log", "Done :)"
    end
  end
end