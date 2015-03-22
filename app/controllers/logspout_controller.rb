class LogspoutController < ApplicationController
  include Tubesock::Hijack

  protect_from_forgery with: :null_session

  # TODO: we should check some security token
  # TODO: we should check that client IP is a mesos slave
  def log
    hijack do |tubesock|
      tubesock.onmessage do |m|
        data = JSON.parse(m)
        log_key = Redis.composite_key('mesos-task', data['name'], 'log')
        log_updates_key = Redis.composite_key('mesos-task', data['name'], 'log-updates')

        # TODO: schedule log save when data reach certain amount
        with_redis do |redis|
          redis.multi do
            redis.lpush(log_key, m)
            redis.publish(log_updates_key, m)
          end
        end
      end
    end
  end
end
