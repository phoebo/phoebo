class SingularityController < ApplicationController
  protect_from_forgery with: :null_session, if: Proc.new { |c| c.request.format == 'application/json' }

  # TODO: we should check some security token
  # TODO: we should check that client IP is a Singularity host

  def deploy
    task_id = parse_task_id(params[:deploy][:requestId])
    head :bad_request and return unless task_id

    data = {}

    case params[:eventType]
    when 'STARTING'
      data[:state] = :deploying
    when 'FINISHED'
      data[:state] = :deployed
    end

    update_task(task_id, data)
    head :ok
  end

  def task
    # Request ID
    task_id = parse_task_id(params[:taskUpdate][:taskId][:requestId])
    head :bad_request and return unless task_id

    # Update payload
    data = {
      mesos_id: params[:taskUpdate][:taskId][:id]
    }

    # Translate task state
    case params[:taskUpdate][:taskState]
    when 'TASK_LAUNCHED'
      data[:state] = :launched
    when 'TASK_RUNNING'
      data[:state] = :running
    when 'TASK_FINISHED'
      data[:state] = :finished
    when 'TASK_FAILED'
      data[:state] = :failed
    end

    # State message
    if params[:taskUpdate][:statusMessage]
      data[:state_message] = params[:taskUpdate][:statusMessage]
    end

    update_task(task_id, data)

    # Render basic HTTP 200 reply
    render plain: "ok"
  end

  private

  def parse_task_id(request_id)
    if m = request_id.match(/^phoebo-([0-9]+)$/)
      return m[1].to_i
    end
  end

  def update_task(task_id, data = {})
    # Update task info
    # Note: We need to add the 'state < ?' condition
    #  because notification can arrive in arbitrary order
    update = data.dup
    update[:state] = Task.states[update[:state]]

    num_affected = Task
        .where(id: task_id, state: Task.valid_prev_states(update[:state]).for_db)
        .update_all(update)

    # Publish state update
    if num_affected > 0
      updates_key = Redis.composite_key('task', task_id, 'updates')

      with_redis do |redis|
        redis.publish updates_key, data.to_json
      end

      # TODO: Schedule log save when task is finished (or failed) and clean up Redis memory
    end
  end
end
