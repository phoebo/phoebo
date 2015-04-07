class LogspoutController < ApplicationController
  include Tubesock::Hijack

  protect_from_forgery with: :null_session
  skip_filter :check_setup

  # TODO: we should check some security token
  # TODO: we should check that client IP is a mesos slave

  def log
    hijack do |tubesock|
      tubesock.onmessage do |m|
        data = JSON.parse(m)
        if b = broker
          b.log_task_output(data['name'], data['data'])
        end
      end
    end
  end
end
