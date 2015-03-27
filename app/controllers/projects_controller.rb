class ProjectsController < ApplicationController
  before_filter :authenticate_user!

  def index
    @gitlab_projects = gitlab.cached_user_projects
    @projects = Project.find_owned_by(current_user).index_by(&:id)
  end

  def refresh
    gitlab.purge_cached_user_projects
    redirect_to action: :index
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
