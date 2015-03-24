class GitlabConnector
  class UnauthorizedError < StandardError; end

  API_PREFIX = '/api/v3'

  def initialize(oauth_token)
    @oauth_token = oauth_token
    @base_url = Rails.configuration.x.gitlab_server.url + API_PREFIX
  end

  # Fetches info about associated user
  def current_user
    get "#{@base_url}/user"
  end

  # Fetches user projects
  def projects
    get "#{@base_url}/projects.json"
  end

  private

  # Shortcut for basic GET request
  def get(url, options = {})
    request_block do
      response = RestClient.get url, options.merge({ accept: :json, authorization: "Bearer #{@oauth_token}" })
      return JSON.parse(response)
    end
  end

  # Request block for handling known errors
  def request_block(&block)
    begin
      block.call
    rescue RestClient::Exception => e
      raise e unless e.response.code == 401
      raise UnauthorizedError
    end
  end

end
