# Information about Gitlab project namespace (group)
class ProjectNamespaceInfo
  attr_reader :id, :path, :name

  def initialize(gitlab_namespace)
    @id          = gitlab_namespace[:id]
    @path        = gitlab_namespace[:path]
    @name        = gitlab_namespace[:name]
  end
end