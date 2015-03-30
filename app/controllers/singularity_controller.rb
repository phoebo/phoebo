class SingularityController < ApplicationController
  protect_from_forgery with: :null_session, if: Proc.new { |c| c.request.format == 'application/json' }
  skip_filter :check_setup

  # TODO: we should check some security token
  # TODO: we should check that client IP is a Singularity host

  def request_webhook
    # Singularity sends notification even for task which are not ours,
    # we need to process them too otherwise they will be sent back repeatedly.
    task_id = Task.parse_request_id(params[:request][:id])
    head :ok and return unless task_id

    data = {}

    case params[:eventType]
    when 'DELETED'
      data[:state] = :deleted
    when 'CREATED'
      head :ok and return
    else
      logger.warn "Unrecognized REQUEST payload received from Singularity: #{JSON.pretty_generate(params[:singularity])}"
      head :ok and return
    end

    update_task(task_id, data)
    head :ok
  end

  def deploy_webhook
    # Singularity sends notification even for task which are not ours,
    # we need to process them too otherwise they will be sent back repeatedly.
    task_id = Task.parse_request_id(params[:deploy][:requestId]) rescue nil
    head :ok and return unless task_id

    data = {}

    case params[:eventType]
    when 'STARTING'
      data[:state] = :deploying
    when 'FINISHED'
      data[:state] = :deployed
    else
      logger.warn "Unrecognized DEPLOY payload received from Singularity: #{JSON.pretty_generate(params[:singularity])}"
      head :ok and return
    end

    update_task(task_id, data)
    head :ok
  end

  def task_webhook
    # Singularity sends notification even for task which are not ours,
    # we need to process them too otherwise they will be sent back repeatedly.
    task_id = Task.parse_request_id(params[:taskUpdate][:taskId][:requestId]) rescue nil
    head :ok and return unless task_id

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
    when 'TASK_KILLED'
      data[:state] = :failed
    else
      logger.warn "Unrecognized TASK payload received from Singularity: #{JSON.pretty_generate(params[:singularity])}"
      head :ok and return
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
