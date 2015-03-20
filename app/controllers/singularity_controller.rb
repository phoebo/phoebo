class SingularityController < ApplicationController
  protect_from_forgery with: :null_session, if: Proc.new { |c| c.request.format == 'application/json' }

  def webhook
    redis.append "log", params.inspect + "\n"
    redis.publish "log", params.inspect

    render plain: "ok"
  end
end
