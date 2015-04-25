class User
  attr_reader :attributes

  DEFAULT_ATTRIBUTES = {
    id: nil,
    name: nil,
    username: nil,
    email: nil,
    is_admin: nil,
    avatar_url: nil,
    oauth_token: nil
  }

  # Declare user with attributes (and fills in default values)
  def initialize(hash = {})
    @attributes = DEFAULT_ATTRIBUTES.merge(hash.symbolize_keys)
  end

  # Define object access to user attributes
  def method_missing(method_name, *args, &block)
    if method_name[-1] == '='
      if @attributes.has_key?(key = method_name[0...-1].to_sym)
        @attributes[key] = args.first
        return
      end
    else
      if @attributes.has_key?(method_name)
        return @attributes[method_name]
      end
    end

    super
  end

  def gitlab
    @gitlab_connector ||= GitlabConnector.new(oauth_token)
  end

  def has_project?(project_id)
    if gitlab.cached_user_projects.include?(project_id)
      return true
    else
      return gitlab.user_projects.include?(project_id)
    end
  end
end
