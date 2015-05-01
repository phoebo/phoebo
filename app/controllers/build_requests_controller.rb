class BuildRequestsController < ApplicationController
  protect_from_forgery with: :null_session, if: Proc.new { |c| c.request.format == 'application/json' }
  before_filter :check_and_load_request, only: [ :show, :create_tasks ]
  before_filter :authenticate_user!, except: [ :show, :create_tasks ]

  def show
    payload = {
      id: @task.id,
      ref: @task.build_ref,
      ssh_user: 'git',
      ssh_public: @project_bindings.settings(:public_key),
      ssh_private: @project_bindings.settings(:private_key),
      ping_url: build_request_tasks_url(@task.build_secret),
      params: @project_bindings.effective_params
    }

    render json: payload
  end

  def create_tasks

    tasks = []
    if params[:tasks]
      params[:tasks].each do |task_params|

        template = {}

        # Name
        unless task_params[:name]
          render json: { error_message: 'Missing task name.' }, status: :bad_request
          return
        end

        # Command
        if task_params[:command]
          template[:command] = task_params[:command].to_s
          task_params.delete(:command)
        end

        # Arguments
        if task_params[:arguments]
          if task_params[:arguments].is_a?(Array)
            template[:arguments] = task_params[:arguments].collect { |item| item.to_s }
          else
            template[:arguments] = [ task_params[:arguments].to_s ]
          end

          task_params.delete(:arguments)
        end

        # Image
        if task_params[:image]
          template[:containerInfo] = {
            docker: {
              image: task_params[:image].to_s
            }
          }
        else
          render json: { error_message: "Missing image for task #{task_params[:name]}." }, status: :bad_request
          return
        end

        # Ports
        if task_params[:ports]
          if task_params[:ports].is_a?(Array)
            unless task_params[:ports].empty?
              template[:containerInfo][:docker][:network] = 'BRIDGE'
              template[:containerInfo][:docker][:portMappings] = task_params[:ports].collect do |port_params|
                unless port_params.is_a?(Hash) || port_params.size != 1
                  render json: { error_message: "Invalid port definition for task #{task_params[:name]}. Use following format: [ { tcp: 1234 } ]." }, status: :bad_request
                  return
                end

                {
                  containerPortType: 'LITERAL',
                  containerPort: port_params.values.first.to_i,
                  hostPortType: 'FROM_OFFER',
                  hostPort: 0,
                  protocol: port_params.keys.first.to_s
                }
              end

              template[:resources] ||= { }
              template[:resources][:numPorts] = task_params[:ports].size
            end
          else
            render json: { error_message: "Invalid port definition for task #{task_params[:name]}. Use following format: [ { tcp: 1234 } ]." }, status: :bad_request
            return
          end

          # Resources
          template[:resources] ||= { }
          template[:resources][:cpus] = @project_bindings.settings(:cpu)
          template[:resources][:memoryMb] = @project_bindings.settings(:memory)

          # Metadata
          template[:metadata] = {}
          template[:metadata][:phoebo_name] = task_params[:name].to_s
          template[:metadata][:phoebo_project_id] = @task.project_id
          template[:metadata][:phoebo_build_ref] = @task.build_ref

          # Brodcast new task
          task = new_task(task_params[:service] ? true : false, template)

          # Add for processing
          tasks << [task.id, template, task_params[:on_demand] ? false : true]
        end
      end
    end

    tasks.each do |args|
      process_task(*args)
    end

    head :ok
  end

  # ----------------------------------------------------------------------------

  def new
    @project_select = []
    ProjectInfo.all_enabled(for_user: current_user).each do |project_info|
      @project_select << [ project_info.display_name, project_info.id ]
    end
  end

  def create
    project_info = ProjectInfo.find(
      params[:build_request][:project_id].to_i,
      for_user: current_user
    )

    unless project_info
      head :not_found
      return
    end

    repo_url = "ssh://" + project_info.repo_url.gsub(/:/, '/').gsub(/^[^@]+@/, '')

    # Request URL
    build_secret = SecureRandom.hex
    url = build_request_url(build_secret)

    # For testing
    # template = {
    #   command: '/bin/bash',
    #   arguments: [ '-c', 'while [ true ]; do date ; sleep 5; done' ],
    #   containerInfo: {
    #     docker: {
    #       image: 'debian:latest'
    #     }
    #   },
    #   metadata: {
    #     phoebo_name: 'Test'
    #   }
    # }

    # For DIND:
    # template = {
    #   arguments: [ 'phoebo', '--from-url', url, '--repo-url', repo_url ],
    #   containerInfo: {
    #     docker: {
    #       image: 'phoebo/phoebo:latest',
    #       privileged: true
    #     }
    #   }
    # }

    # For shared docker with the host:
    template = {
      arguments: [ 'phoebo', '--from-url', url, '--repository', repo_url ],
      env: {
        :NO_DIND => 1,
        :DOCKER_URL => 'unix:///tmp/docker.sock'
      },
      containerInfo: {
        volumes: [
          { hostPath: '/var/run/docker.sock', containerPath: '/tmp/docker.sock', mode: 'RW' }
        ],
        docker: {
          image: 'phoebo/phoebo:latest'
        }
      }
    }

    # Ref / Branch
    if params[:build_request][:branch] =~ /[0-9a-f]{40}/
      ref = params[:build_request][:branch]
    else
      ref = project_info.default_branch
    end

    # Append metadata
    template[:metadata]                       ||= {}
    template[:metadata][:phoebo_name]         ||= 'Image Builder'
    template[:metadata][:phoebo_project_id]   ||= project_info.id
    template[:metadata][:phoebo_build_ref]    ||= ref
    template[:metadata][:phoebo_build_secret] ||= build_secret

    # Brodcast new task
    task = new_task(false, template)

    # Send request to singularity
    process_task(task.id, template)

    # Redirect
    redirect_to tasks_path
  end

  # ----------------------------------------------------------------------------
  private

  def new_task(daemon, template)
    task = broker.new_task do |task|
      task.state = Broker::Task::STATE_FRESH
      task.daemon = daemon
      template[:metadata].each do |k, v|
        if m = k.to_s.match(/^phoebo_(.+)$/)
          if Broker::Task.method_defined?(sym = "#{m[1]}=".to_sym)
            task.send(sym, v)
          end
        end
      end
    end
  end

  def process_task(task_id, template, run = true)
    daemon = broker.task(task_id).daemon

    singularity = SingularityConnector.new
    request_info = singularity.create_request(nil, daemon)

    broker.update_task(task_id) do |task|
      task.request_id = request_info[:request][:id]
    end

    singularity.create_deploy(request_info, template)

    if run && !daemon
      singularity.run_request(request_info[:request][:id])
    end

  rescue => e
    broker.update_task(task_id) do |task|
      task.state         = Broker::Task::STATE_REQUEST_FAILED,
      task.state_message = e.message
    end
  end

  def check_and_load_request
    task_id, @task = broker.tasks.find { |task_id, task| task.build_secret == params[:request_secret] }
    unless @task
      sleep 1
      head :not_found
      return
    end

    # TODO: we need to get namespace_id
    #  (we can't just use ProjectInfo, because we are without gitlab context)
    @project_bindings = ProjectAccessor.new(nil, @task.project_id)
  end

end
