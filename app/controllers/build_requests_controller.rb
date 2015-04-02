class BuildRequestsController < ApplicationController
  protect_from_forgery with: :null_session, if: Proc.new { |c| c.request.format == 'application/json' }
  before_filter :check_and_load_request, only: [ :show, :create_tasks ]
  before_filter :authenticate_user!, except: [ :show, :create_tasks ]

  def show
    payload = {
      id: @build_request.id,
      repo_url: "ssh://" + @build_request.project.repo_url.gsub(/:/, '/').gsub(/^[^@]+@/, ''),
      ssh_user: 'git',
      ssh_public: @build_request.project.public_key,
      ssh_private: @build_request.project.private_key,
      ping_url: build_request_tasks_url(@build_request.secret, Rails.configuration.x.url)
    }

    render json: payload
  end

  def create_tasks

    start_tasks = []

    ActiveRecord::Base.transaction do
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
        end

        # Create task from template
        task = Task.create(
          name: task_params[:name].to_s,
          kind: task_params[:service] ? :service : :oneoff,
          build_request: @build_request,
          deploy_template: template
        )

        # On demand
        unless task_params[:on_demand]
          start_tasks << task
        end
      end
    end

    start_tasks.each do |task|
      ScheduleJob.perform_later task
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
    task = nil

    # TODO: check if project exists
    project_info = gitlab.cached_project(params[:build_request][:project_id].to_i)

    ActiveRecord::Base.transaction do
      request = BuildRequest.create(params.require(:build_request).permit(:project_id).merge({ ref: project_info[:default_branch] }))
      url = build_request_url(request.secret, Rails.configuration.x.url)

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

      task = Task.create(
        name: 'Image build',
        build_request: request,
        deploy_template: template
      )
    end

    payload = TasksController::UpdateStream.build_notification_payload(project_info, task)

    with_redis do |redis|
      redis.publish task.updates_channel, payload.to_json
    end

    ScheduleJob.perform_later task
    redirect_to task_path(task)
  end

  # ----------------------------------------------------------------------------
  private

  def check_and_load_request
    unless @build_request = BuildRequest.find_by(secret: params[:request_secret])
      sleep 1
      head :not_found
      return
    end
  end

end
