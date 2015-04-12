class BuildRequestsController < ApplicationController
  protect_from_forgery with: :null_session, if: Proc.new { |c| c.request.format == 'application/json' }
  before_filter :check_and_load_request, only: [ :show, :create_tasks ]
  before_filter :authenticate_user!, except: [ :show, :create_tasks ]

  def show
    project = Project.find(@task.project_id)
    payload = {
      id: @task.id,
      repo_url: "ssh://" + project.repo_url.gsub(/:/, '/').gsub(/^[^@]+@/, ''),
      ssh_user: 'git',
      ssh_public: project.public_key,
      ssh_private: project.private_key,
      ping_url: build_request_tasks_url(@task.build_secret, Rails.configuration.x.url)
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
    Project.find_owned_by(current_user).each do |project|
      @project_select << [ project.name, project.id ]
    end
  end

  def create
    # TODO: check if project exists
    project_id   = params[:build_request][:project_id].to_i
    project_info = gitlab.cached_project(project_id)

    # Request URL
    build_secret = SecureRandom.hex
    url = build_request_url(build_secret, Rails.configuration.x.url)

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
    #   arguments: [ 'phoebo', '--from-url', url ],
    #   containerInfo: {
    #     docker: {
    #       image: 'phoebo/phoebo:latest',
    #       privileged: true
    #     }
    #   }
    # }

    # For shared docker with the host:
    template = {
      arguments: [ 'phoebo', '--from-url', url ],
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

    # Append metadata
    template[:metadata]                       ||= {}
    template[:metadata][:phoebo_name]         ||= 'Image Builder'
    template[:metadata][:phoebo_project_id]   ||= project_id
    template[:metadata][:phoebo_build_ref]    ||= project_info[:default_branch]
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
  end

end
