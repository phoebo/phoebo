class TasksController < ApplicationController
  include Tubesock::Hijack

  before_filter :authenticate_user!

  def index
    js update_stream_url: watch_tasks_path
  end

  def watch
    projects = current_user.gitlab.cached_user_projects
    hijack do |tubesock|
      subscriber = nil

      tubesock.onopen do
        subscriber = broker.new_subscriber

        subscriber.handle :task_update do |new_task, old_task, diff|
          data = diff.nil? ? new_task.to_h : diff

          # Add project info
          if data[:project_id] && (project = projects[data[:project_id]])
            data[:project_name] = [ project[:namespace][:name], project[:name] ]
          end

          # Add state no matter what
          data[:state] = new_task.state

          tubesock.send_data({ new_task.id => data }.to_json)
        end

        subscriber.handle :task_output do |task, data|
          tubesock.send_data({ task.id => { log: data } }.to_json)
        end

        subscriber.subscribe_for :task_update
        tubesock.send_data('subscribed'.to_json);
      end

      tubesock.onmessage do |message|
        begin
          data = JSON.parse(message, symbolize_names: true)

          if data[:subscribe_for_log]
            subscriber.subscribe_for :task_output, id: data[:subscribe_for_log].to_i
          elsif data[:unsubscribe_from_log]
            subscriber.unsubscribe_from :task_output, id: data[:unsubscribe_from_log].to_i
          end

        rescue JSON::ParserError
          puts "Warning: invalid message received #{message}"
        end
      end

      tubesock.onclose do
        subscriber.detach
      end
    end
  end

  def destroy
    # TODO: check if user can remove this task (project_id)
    # TODO: CSRF
    if task = broker.task(params[:task_id].to_i)
      ok = false
      broker.update_task(task.id) do |task|
        if task.state != Broker::Task::STATE_DELETING
          task.state = Broker::Task::STATE_DELETING;
          ok = true
        end
      end

      if task.request_id && ok
        singularity = SingularityConnector.new
        singularity.remove_request(task.request_id)
      end

      head :ok
      return
    end

    head :not_found
  end
end
