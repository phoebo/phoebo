class TasksController < ApplicationController
  include Tubesock::Hijack

  before_filter :authenticate_user!

  # Check and load project
  before_filter :load_projects, only: [ :index, :watch ]

  def index
    if @projects.empty?
      # TODO: some flash message?
      redirect_to tasks_path
      return
    end

    if params[:namespace]
      if params[:project]
        if params[:build_ref]
          watch_url = watch_build_tasks_path(params[:namespace], params[:project], params[:build_ref])
        else
          watch_url = watch_project_tasks_path(params[:namespace], params[:project])
        end
      else
        watch_url = watch_namespace_tasks_path(params[:namespace])
      end
    else
      watch_url = watch_tasks_path
    end

    js update_stream_url: watch_url
  end

  def watch
    hijack do |tubesock|
      subscriber = nil

      tubesock.onopen do
        if @projects.empty?
          tubesock.close
        else
          subscriber = broker.new_subscriber

          tubesock.onclose do
            subscriber.detach
          end

          subscriber.handle :task_update do |new_task, old_task, diff|
            data = diff.nil? ? new_task.to_h : diff

            # Add project info
            if data[:project_id] && (project = @projects[data[:project_id]])
              data[:project_name] = [ project[:namespace][:name], project[:name] ]
            end

            # Add state no matter what
            data[:state] = new_task.state

            tubesock.send_data({ new_task.id => data }.to_json)
          end

          subscriber.handle :task_output do |task, data|
            if data.is_a? Enumerable
              data.each_with_index do |current_data, index|
                tubesock.send_data({ task.id => { log: current_data, batch: true } }.to_json)
              end

              tubesock.send_data({ task.id => { log: nil, end_of_batch: true } }.to_json)
            else
              tubesock.send_data({ task.id => { log: data } }.to_json)
            end
          end

          project_ids = @projects.keys
          project_ids << nil if current_user.is_admin && params[:namespace].nil?

          subscriber.subscribe_for :task_update, project_id: project_ids
          tubesock.send_data('subscribed'.to_json);
        end
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

  private

  def load_projects
    @projects = current_user.gitlab.cached_user_projects

    if @projects.empty?
      redirect_to help_no_projects_path
      return
    end

    if params[:namespace]
      @projects.select! do |key, project|
        if project[:namespace] && project[:namespace][:path] == params[:namespace]
          if params[:project]
            project[:path] == params[:project]
          else
            true
          end
        else
          false
        end
      end
    end
  end
end
