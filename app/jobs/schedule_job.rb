class ScheduleJob < ActiveJob::Base
  queue_as :default

  def perform(task)
    # Set task state as REQUESTING
    # Stop if task was in the invalid state
    unless update_task(task, state: :requesting) > 0
      return
    end

    schedule(task)

    # Update task state to REQUESTED
    update_task(task, state: :requested)

  rescue => e
    # Update task state to REQUEST_FAILED
    update_task(task, state: :request_failed, state_message: e.message)
  end

  private

  def update_task(task, options)
    data = options.dup
    data[:state] = Task.states[data[:state]]

    num_affected = Task
        .where(id: task.id, state: Task.valid_prev_states(options[:state]).for_db)
        .update_all(data)

    if num_affected > 0
      with_redis do |redis|
        redis.publish task.updates_channel, options.to_json
      end
    end

    num_affected
  end

  # ----------------------------------------------------------------------------

  def schedule(task)
    singularity = SingularityConnector.new
    request_info = singularity.create_request(task.request_id)
    singularity.create_deploy(request_info, task.deploy_template)
    singularity.run_request(task.request_id)
  end

end
