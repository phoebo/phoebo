class BuildRequestsController < ApplicationController
  protect_from_forgery with: :null_session, if: Proc.new { |c| c.request.format == 'application/json' }

  def show
    unless request = BuildRequest.find_by(secret: params[:request_secret])
      sleep 1
      head :not_found
      return
    end

    payload = {
      id: request.id,
      repo_url: "ssh://" + request.project.repo_url.gsub(/:/, '/').gsub(/^[^@]+@/, ''),
      ssh_user: 'git',
      ssh_public: request.project.public_key,
      ssh_private: request.project.private_key
    }

    render json: payload
  end

  def new
    @project_select = []
    Project.find_owned_by(current_user).each do |project|
      @project_select << [ project.name, project.id ]
    end
  end

  def create
    task = nil

    # TODO: check if project exists
    project_info = gitlab.cached_project(params[:build_request][:project_id])

    ActiveRecord::Base.transaction do
      request = BuildRequest.create(params.require(:build_request).permit(:project_id).merge({ ref: project_info[:default_branch] }))

      # url = build_request_url(request.secret)
      url = 'http://10.10.3.230:3000' + build_request_path(request.secret)

      template = {
        arguments: [ "phoebo --from-url \"#{url}\" 2>&1"],
        containerInfo: {
          docker: {
            image: 'phoebo/phoebo:latest',
            privileged: true
          }
        }
      }

      task = Task.create(
        build_request: request,
        deploy_template: template
      )
    end

    with_redis do |redis|
      updates_key = Redis.composite_key('task', task.id, 'updates')
      redis.publish updates_key, { state: task.state }.to_json
    end

    redirect_to tasks_path
  end
end
