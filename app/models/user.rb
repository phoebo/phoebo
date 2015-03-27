class User
  attr_reader :attributes

  def initialize(hash)
    @attributes = hash
  end

  def method_missing(meth, *args, &block)
    if attributes.has_key?(meth.to_s)
      attributes[meth.to_s]
    else
      super
    end
  end

  def gitlab
    @gitlab_connector ||= GitlabConnector.new(oauth_token)
  end
end
