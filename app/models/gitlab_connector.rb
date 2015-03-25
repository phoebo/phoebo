# @see https://github.com/gitlabhq/gitlabhq/tree/master/doc/api
class GitlabConnector
  class UnauthorizedError < StandardError; end

  API_PREFIX = '/api/v3'

  def self.def_cached_helper(method_id, id, options, &block)
    define_method(method_id) do |*args|
      cache_key = instance_eval { send("cache_key_for_#{id}".to_sym, *args) }
      Rails.cache.fetch(cache_key, options) do
         instance_exec(*args, &block)
      end
    end
  end

  def self.def_cached(id, options = {}, &block)

    # Defaults
    options[:expires_in] = 12.hours unless options[:expires_in]

    # Define cache key getter
    cached_key_for_method = "cache_key_for_#{id}".to_sym
    if options.delete(:global)
      define_method(cached_key_for_method) do |*args|
        "connector_cache:#{id}" + (args.empty? ? "" : ":" + args.join(':'))
      end
    else
      define_method(cached_key_for_method) do |*args|
        oauth_token = instance_variable_get(:@oauth_token)
        "connector_cache:#{oauth_token}:#{id}" + (args.empty? ? "" : ":" + args.join(':'))
      end
    end

    # Define purge helper
    define_method("purge_cached_#{id}".to_sym) do |*args|
      cache_key = instance_eval { send("cache_key_for_#{id}".to_sym, *args) }
      Rails.cache.delete(cache_key)
    end

    # Define cached version
    def_cached_helper("cached_#{id}".to_sym, id, options, &block)

    # Define uncached version
    def_cached_helper(id, id, options.merge({ force: true }), &block)
  end

  # ----------------------------------------------------------------------------

  def initialize(oauth_token)
    @oauth_token = oauth_token
    @base_url = Rails.configuration.x.gitlab_server.url + API_PREFIX
  end

  # Fetches info about associated user
  def_cached :current_user do
    get("#{@base_url}/user").parsed
  end

  # Fetches user projects
  def_cached :user_projects do
    get_all "#{@base_url}/projects/owned"
  end

  # Fetch single project info
  def_cached :project, global: true do |project_id|
    get("#{@base_url}/projects/#{Rack::Utils.escape(project_id)}").parsed
  end

  # Add deploy key to project
  def add_deploy_key(project_id, name, key)
    payload = {
      title: name,
      key: key
    }

    post("#{@base_url}/projects/#{Rack::Utils.escape(project_id)}/keys", payload)
  end

  # ----------------------------------------------------------------------------
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

  # Performs HTTP POST request
  def post(url, payload, options = {})
    options.merge!({ content_type: :json, accept: :json, authorization: "Bearer #{@oauth_token}" })
    RestClient.post(url, payload.to_json, options, &method(:request_block))
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
