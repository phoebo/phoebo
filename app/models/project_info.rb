# Combined info of GitLab project with our project settings
class ProjectInfo
  attr_reader :id, :path, :name
  attr_reader :default_branch, :repo_url
  attr_reader :project_set, :namespace

  def initialize(gitlab_project, project_set)
    @id             = gitlab_project[:id]
    @path           = gitlab_project[:path]
    @name           = gitlab_project[:name]
    @repo_url       = gitlab_project[:ssh_url_to_repo]
    @default_branch = gitlab_project[:default_branch]

    @namespace      = ProjectNamespaceInfo.new(gitlab_project[:namespace])
    @project_set    = project_set
  end

  def enabled?
    !!@project_set
  end

  def display_name
    n = []
    n << @namespace.name if @namespace
    n << @name

    n.join(' / ')
  end

  class << self
    # Returns collection of all users projects
    def all(options)
      gitlab = options[:for_user].gitlab
      gitlab_projects = gitlab.cached_user_projects
      user_project_ids = gitlab_projects.keys

      matching_sets = ProjectSet.where(
        kind: ProjectSet.kinds[:with_project_id],
        filter_pattern: user_project_ids
      ).index_by(&:filter_pattern)

      projects = []
      gitlab_projects.each do |_, gitlab_project|
        projects << self.new(
          gitlab_project,
          matching_sets["#{gitlab_project[:id]}"]
        )
      end

      projects
    end

    # Returns collection of all enabled projects available to given user
    def all_enabled(options)
      all(options).select do |project_info|
        project_info.enabled?
      end
    end

    # Finds project by it's Gitlab ID
    def find(id, options)
      # Note: We don't want to cache the project query, because
      #  GitlabConnector might return project info even if it is not managable
      #  for given user
      gitlab         = options[:for_user].gitlab
      gitlab_project = gitlab.project(id)

      return nil unless gitlab_project

      self.new(
        gitlab_project,
        ProjectSet.for_project(gitlab_project[:id], init: !!options[:project_set_init])
      )
    end

    # Finds project by it's path (namespace / project)
    def find_by_path(namespace_path, project_path, options)
      gitlab            = options[:for_user].gitlab
      matching_projects = gitlab.cached_user_projects.select do |_, project|
        if project[:namespace] && project[:namespace][:path] == namespace_path
          project[:path] == project_path
        else
          false
        end
      end

      return nil if matching_projects.empty?
      gitlab_project = matching_projects.values.first

      self.new(
        gitlab_project,
        ProjectSet.for_project(gitlab_project[:id], init: !!options[:project_set_init])
      )
    end
  end
end