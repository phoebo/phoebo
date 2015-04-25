class ProxyAccessController < ApplicationController
  before_filter :check_and_load_proxy_request
  layout 'simple'


  def update

    # Check password
    if params[:proxy_access] && password = params[:proxy_access][:password]
      if !@project_bindings || password != @project_bindings.settings(:proxy_password)
        flash[:danger] = 'Invalid password'
        redirect_to action: :show
        return
      end

    # Check logged user if not password is available
    elsif !current_user_allowed?
      redirect_to action: :show
      return
    end

    # Continue if passed authentication ----

    # Resolve runner hostname to IP
    resolver = Resolv::Hosts.new
    unless addr = resolver.getaddress(@task.runner_host)
      render plain: 'Unable to resolve runner hostname', status: 500
      return
    end

    # Prepare token info
    token_info = @task.proxy_ports.collect do |scheme, port|
      [ scheme, port ? "#{addr}:#{port}" : nil ]

    end.to_h

    # Set token info
    with_redis do |redis|
      redis.set(
        Redis.composite_key('proxy', 'tokens', params[:request_id]),
        token_info.to_json,
        ex: 3600
      )
    end

    # Build URL for redirection and redirect
    url  = @proxy_request[:scheme] + "://"
    unless @proxy_request[:host].start_with?(ref = @task.build_ref[0...8] + ".")
      url += ref
    end

    url += @proxy_request[:host]

    case @proxy_request[:scheme]
    when 'http'
      url += ":#{@proxy_request[:port]}" if @proxy_request[:port] != "80"
    when 'https:'
      url += ":#{@proxy_request[:port]}" if @proxy_request[:port] != "443"
    else
      url += ":#{@proxy_request[:port]}"
    end

    url += @proxy_request[:uri]
    redirect_to url
  end

  def current_user_allowed?
    if current_user
      if @task.project_id
        return current_user.has_project?(@task.project_id)
      else
        return current_user.is_admin ? true : false
      end
    else
      return false
    end
  end

  helper_method :current_user_allowed?

  def project_password?
    if @project_bindings
      return !@project_bindings.settings(:proxy_password).nil?
    end

    false
  end

  helper_method :project_password?

  private

  def check_and_load_proxy_request
    # Check request id
    unless params[:request_id]
      render plain: 'Invalid request. Missing proxy request id.', status: 400
      return
    end

    # Load request from Redis
    request_data = nil
    with_redis do |redis|
      request_data = redis.get(Redis.composite_key('proxy', 'requests', params[:request_id]))
    end

    # Parse request data
    if request_data
      begin
        @proxy_request = JSON.parse(request_data, symbolize_names: true)

      rescue JSON::ParserError
        render plain: 'Invalid request. Malformed request data.', status: 400
        return
      end
    else
      render plain: 'No such request.', status: 404
      sleep 1
      return
    end

    # Parse request data
    if @proxy_request[:host]
      uri = URI(request.url)
      default_host = Rails.application.routes.default_url_options[:host]
      host = @proxy_request[:host].downcase

      if host.end_with?(".#{default_host.downcase}")
        subdomains = host[0...(0 - default_host.length - 1)].split('.')
        @proxy_request[:service_name] = subdomains[-1]
        @proxy_request[:build_ref] = subdomains[-2]
      end
    end

    # Load task info
    @task = catch(:finder) do
      # Reverse to ensure we get to newest tasks first
      broker.tasks.reverse_each do |_, task|
        if task.service_name == @proxy_request[:service_name]
          if !@proxy_request[:build_ref] || task.build_ref.start_with?(@proxy_request[:build_ref])
            throw(:finder, task)
          end
        end
      end

      render 'not_found', status: 404
      return
    end

    # Check that there is some proxy-able service
    unless @task.proxy_ports && @task.runner_host
      render 'not_found', status: 404
      return
    end

    # Project bindings
    if @task.project_id
      # TODO: we need to get namespace_id
      #  (we can't just use ProjectInfo, because we are without gitlab context)
      @project_bindings = ProjectAccessor.new(nil, @task.project_id)
    end
  end
end
