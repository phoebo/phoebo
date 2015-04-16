Struct.new('ProjectInfo', :id, :path, :name, :enabled, :namespace)
Struct.new('ProjectNamespaceInfo', :id, :path, :name)

class ProjectsController < ApplicationController
  before_filter :authenticate_user!

  def index
    gitlab_projects = gitlab.cached_user_projects
    ci_projects = Project.find_owned_by(current_user).index_by(&:id)

    @enabled_projects  = []
    @available_projects = []

    gitlab_projects.each do |_, gitlab_project|
      project = Struct::ProjectInfo.new(gitlab_project[:id], gitlab_project[:path], gitlab_project[:name])
      project.namespace = Struct::ProjectNamespaceInfo.new(gitlab_project[:namespace][:id], gitlab_project[:namespace][:path], gitlab_project[:namespace][:name])

      if ci_projects[gitlab_project[:id]]
        project.enabled = true
        @enabled_projects << project
      else
        project_enabled = false
        @available_projects << project
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

  def refresh
    gitlab.purge_cached_user_projects
    redirect_to action: :index
  end

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
    gitlab_project = gitlab.project(params[:project_id])

    # Generate new 2048 bit RSA key
    # Note: must have comment otherwise it doesn't get read by some clients
    k = SSHKey.generate(comment: 'user@domain.tld')

    # Add new deploy key to the project
    gitlab.add_deploy_key(
      gitlab_project[:id],
      'Phoebo CI',
      k.ssh_public_key
    )

    # Save project info
    project = Project.create(
      id: gitlab_project[:id],
      name: gitlab_project[:name],
      path: gitlab_project[:path],
      namespace_name: gitlab_project[:namespace][:name],
      namespace_path: gitlab_project[:namespace][:path],
      url: gitlab_project[:web_url],
      repo_url: gitlab_project[:ssh_url_to_repo],
      public_key: k.ssh_public_key,
      private_key: k.private_key
    )

    redirect_to action: :index
  end
end
