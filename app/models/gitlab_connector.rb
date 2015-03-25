# @see https://github.com/gitlabhq/gitlabhq/tree/master/doc/api
class GitlabConnector
  class UnauthorizedError < StandardError; end

  API_PREFIX = '/api/v3'

  def initialize(oauth_token)
    @oauth_token = oauth_token
    @base_url = Rails.configuration.x.gitlab_server.url + API_PREFIX
  end

  # Fetches info about associated user
  def current_user
    get("#{@base_url}/user").parsed
  end

  # Fetches user projects
  def user_projects
    get_all "#{@base_url}/projects/owned"
  end

  # Fetch single project info
  def project(project_id)
    get("#{@base_url}/projects/#{Rack::Utils.escape(project_id)}").parsed
  end

  private

  # GET all records while handling the pagination
  def get_all(url, initial_options = {})
    options = initial_options.clone
    options[:params] ||= {}
    options[:params][:page] = 1
    options[:params][:per_page] = 100 # maximum number of records per page

    data = []
    begin
      response = get(url, options)
      data = data.concat(response.parsed)
      options = initial_options
    end while url = response.hateoas[:next]

    data
  end

  # Performs basic HTTP GET request
  def get(url, options = {})
    options.merge!({ accept: :json, authorization: "Bearer #{@oauth_token}" })
    RestClient.get(url, options, &method(:request_block))
  end

  # Handles response
  def request_block(response, request, result, &block)
    # Extend with HATEOAS helper
    # Note: we do not want to declare it globally, because it is specific to
    #   Gitlab API
    response.define_singleton_method :hateoas do
      unless response.instance_variable_defined? :@hateoas
        links = response.instance_variable_set(:@hateoas, {})

        if response.headers[:link]
          parts = response.headers[:link].split(/,\s*/)
          parts.each do |part|
            if m = part.match(/<([^>]+)>(;\s+rel="([^"]+)")?/)
              links[m[3] ? m[3].to_sym : :self] = m[1]
            end
          end
        end
      end

      response.instance_variable_get :@hateoas
    end

    # Extend with parsing helper
    response.define_singleton_method :parsed do
      unless response.instance_variable_defined? :@parsed
        response.instance_variable_set(:@parsed, JSON.parse(response, symbolize_names: true))
      end

      response.instance_variable_get :@parsed
    end

    # Raise our custom exception on HTTP 401
    # (we are catching it in the controller filter and redirecting to login)
    case response.code
    when 401
      raise UnauthorizedError
    else
      response.return!(request, result, &block)
    end
  end

end
