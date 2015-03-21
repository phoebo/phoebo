class SingularityController < ApplicationController
  protect_from_forgery with: :null_session, if: Proc.new { |c| c.request.format == 'application/json' }

  # TODO: we should check some security token
  # TODO: we should check that client IP is a Singularity host
  def webhook
    # Request id
    request_id = params[:task][:taskRequest][:request][:id]

    # Translate task state
    case params[:taskUpdate][:taskState]
    when 'TASK_LAUNCHED'
      new_state = :launched
    when 'TASK_RUNNING'
      new_state = :running
    when 'TASK_FINISHED'
      new_state = :finished
    end

    # Update task info
    # Note: We need to add the 'state < ?' condition
    #  because notification can arrive in arbitrary order
    num_affected = Task.where('id = ?', request_id)
        .where('state < ?', Task.states[new_state])
        .update_all(
          mesos_id: params[:taskUpdate][:taskId][:id],
          state: Task.states[new_state]
        )

    # Note: This takes care of escaping request_id, because it forces
    #   only situations when it actually exists
    if num_affected > 0

      # Publish state change to subscribers
      redis.publish "task-#{request_id}", { state: new_state }.to_json
    end

    # Render basic HTTP 200 reply
    render plain: "ok"
  end
end
