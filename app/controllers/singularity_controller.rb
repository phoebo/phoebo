class SingularityController < ApplicationController
  protect_from_forgery with: :null_session, if: Proc.new { |c| c.request.format == 'application/json' }

  # TODO: we should check some security token
  # TODO: we should check that client IP is a Singularity host
  def webhook
    # puts "Webhook:", JSON.pretty_generate(params)

    # Request id
    request_id = params[:task][:taskRequest][:request][:id]
    mesos_id = params[:taskUpdate][:taskId][:id]

    if m = request_id.match(/^phoebo-([0-9]+)$/)
      task_id = m[1].to_i
    else
      head :bad_request
      return
    end

    # Translate task state
    case params[:taskUpdate][:taskState]
    when 'TASK_LAUNCHED'
      new_state = :launched
    when 'TASK_RUNNING'
      new_state = :running
    when 'TASK_FINISHED'
      new_state = :finished
    when 'TASK_FAILED'
      new_state = :failed
    end

    # Update task info
    # Note: We need to add the 'state < ?' condition
    #  because notification can arrive in arbitrary order
    num_affected = Task
        .where(id: task_id, state: Task.valid_prev_states(new_state).for_db)
        .update_all(
          mesos_id: mesos_id,
          state: Task.states[new_state]
        )

    # Publish state update
    if num_affected > 0
      updates_key = Redis.composite_key('task', task_id, 'updates')

      with_redis do |redis|
        redis.publish updates_key, { mesos_id: mesos_id, state: new_state }.to_json
      end

      # TODO: Schedule log save when task is finished (or failed) and clean up Redis memory
    end

    # Render basic HTTP 200 reply
    render plain: "ok"
  end
end
