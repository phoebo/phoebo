class SingularityController < ApplicationController
  class Error < StandardError; end
  class NotFoundError < Error; end

  rescue_from Error do |e|
    logger.warn "Error while processing #{action_name}: #{e.message}" + (e.is_a?(NotFoundError) ? "" : "\n#{JSON.pretty_generate(params[:singularity])}")

    # Singularity sends notification even for task which are not ours,
    # we need to process them too otherwise they will be sent back repeatedly.
    head :ok
  end

  protect_from_forgery with: :null_session, if: Proc.new { |c| c.request.format == 'application/json' }
  skip_filter :check_setup

  # TODO: we should check some security token
  # TODO: we should check that client IP is a Singularity host

  # before_filter do
  #   puts "#{request.method.upcase} #{URI(request.url).path}"
  #   puts JSON.pretty_generate(params[:singularity])
  # end

  def task(request_id, run_id = nil)
    task_id, task = broker.tasks.find do |_, task|
      task.request_id == request_id &&
        (run_id.nil? || (task.run_id.nil? || task.run_id == run_id))
    end

    task
  end

  def request_webhook
    task = task(request_id = params[:request][:id])
    raise NotFoundError.new("No task found for request id: #{request_id}") unless task

    case params[:eventType]
    when 'DELETED'
      broker.remove_task(task.id)

    when 'CREATED', 'UPDATED'
      broker.update_task(task.id) do |task|
        if task.valid_next_state?(Broker::Task::STATE_REQUESTED)
          task.state = Broker::Task::STATE_REQUESTED
        end
      end

    else
      raise Error.new("Unexpected event type")
    end

    head :ok
  end

  def deploy_webhook

    task = task(request_id = params[:deployMarker][:requestId])
    raise NotFoundError.new("No task found for request id: #{request_id}") unless task

    case params[:eventType]
    when 'STARTING'
      state = Broker::Task::STATE_DEPLOYING
    when 'FINISHED'
      state = Broker::Task::STATE_DEPLOYED
    else
      raise Error.new("Unexpected event type")
    end

    broker.update_task(task.id) do |task|
      if task.valid_next_state?(state)
        task.state = state
      end
    end

    head :ok
  end

  def task_webhook
    task = task(
      request_id = params[:taskUpdate][:taskId][:requestId],
      run_id = params[:taskUpdate][:taskId][:id]
    )

    raise NotFoundError.new("No task found for request id: #{request_id}, run id: #{run_id}") unless task

    # Translate task state
    case params[:taskUpdate][:taskState]
    when 'TASK_LAUNCHED'
      state = :launched
    when 'TASK_RUNNING'
      state = :running
    when 'TASK_FINISHED'
      state = :finished
    when 'TASK_FAILED'
      state = :failed
    when 'TASK_KILLED'
      state = :failed
    when 'TASK_LOST'
      broker.remove_task(task.id)
      head :ok
      return
    else
      raise Error.new("Unexpected task state")
    end

    broker.update_task(task.id) do |task|
      # Check task state
      if task.valid_next_state?(state)
        task.state = state
        task.state_message = params[:taskUpdate][:statusMessage] ? params[:taskUpdate][:statusMessage] : nil
        task.run_id = params[:taskUpdate][:taskId][:id]

        # Offer
        if params[:task][:offer]
          # Mesos slave id
          if params[:task][:offer][:slaveId][:value]
            task.runner_slave_id = params[:task][:offer][:slaveId][:value]
          end

          # Mesos slave host
          if params[:task][:offer][:hostname]
            task.runner_host = params[:task][:offer][:hostname]
          end
        end

        # Mesos task
        if params[:task][:mesosTask]
          if params[:task][:mesosTask][:container][:docker][:portMappings]
            task.port_mappings = params[:task][:mesosTask][:container][:docker][:portMappings]
          end
        end
      end
    end

    head :ok
  end
end
