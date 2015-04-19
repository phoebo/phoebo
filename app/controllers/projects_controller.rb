class ProjectsController < ApplicationController
  before_filter :authenticate_user!

  # List of all user projects
  def index
    @enabled_projects   = []
    @available_projects = []

    ProjectInfo.all(for_user: current_user).each do |project_info|
      if project_info.enabled?
        @enabled_projects << project_info
      else
        @available_projects << project_info
      end
    end

    [ @enabled_projects, @available_projects ].each do |ary|
      ary.sort! do |a, b|
        if a.namespace.id == b.namespace.id
          a.name.casecmp(b.name)
        else
          a.namespace.name.casecmp(b.namespace.name)
        end
      end
    end
  end

  # Purge cache of Gitlab projects
  def refresh
    gitlab.purge_cached_user_projects
    redirect_to action: :index
  end

  # List important project commits (branch heads)
  def commits
    commits = [ ]
    gitlab.project_branches(params[:project_id]).each do |branch_info|
      commits << {
        id: branch_info[:commit][:id],
        branch: branch_info[:name],
        message: branch_info[:commit][:message]
      }
    end

    render json: { commits: commits }
  end

  def enable
    project_info = ProjectInfo.find(
      params[:project_id],
      for_user: current_user,
      project_set_init: true
    )

    unless project_info
      head :not_found
      return
    end

    project_set = project_info.project_set
    project_set.settings ||= ProjectSettings.new

    unless project_set.settings.public_key
      # Generate new 2048 bit RSA key
      # Note: must have comment otherwise it doesn't get read by some clients
      k = SSHKey.generate(comment: 'user@domain.tld')
      project_set.settings.public_key = k.ssh_public_key
      project_set.settings.private_key = k.private_key
      project_set.save

      gitlab.add_deploy_key(
        project_info.id,
        'Phoebo CI',
        project_set.settings.public_key
      )
    end

    flash[:success] = "CI enabled for project #{project_info.display_name}."
    redirect_to action: :index
  end

  def disable
    project_info = ProjectInfo.find(
      params[:project_id],
      for_user: current_user
    )

    unless project_info && project_info.project_set
      head :not_found
      return
    end

    settings = project_info.project_set.settings
    if settings.public_key
      matching_keys = gitlab.deploy_keys(project_info.id).select do |_, key|
        key[:key] == settings.public_key
      end

      matching_keys.each do |_, key|
        gitlab.del_deploy_key(project_info.id, key[:id])
      end
    end

    project_info.project_set.destroy

    flash[:success] = "CI disabled for project #{project_info.display_name}."
    redirect_to action: :index
  end
end
