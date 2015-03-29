class SingularityConnector

  attr_reader :config

  # Constructor
  def initialize(config = nil)
    @config = config || Rails.configuration.x.singularity
  end

  # Install webhook if necessary
  def install_webhook(url)
    payload = {
      id: 'phoebo',
      uri: url,
      type: :TASK
    }

    response = get "#{config.url}/api/webhooks"
    webhook_info = response.parsed
    webhook_info.select! { |v| v[:id] == payload[:id] }

    if webhook_info.size == 0 || webhook_info[0].deep_diff(payload).size > 0
      RestClient.delete("#{config.url}/api/webhooks/" + Rack::Utils.escape(payload[:id]), accept: :json, &method(:request_block))
    else
      return
    end

    post "#{config.url}/api/webhooks", payload
  end

  # Create Singularity request if does not exist
  def create_request(request_id, is_service = false)
    url = "#{config.url}/api/requests/request/" + Rack::Utils.escape(request_id)
    begin
      response = get url
    rescue RestClient::Exception => e
      raise e unless e.response.code == 404

      payload = {
        id: request_id,
        daemon: is_service
      }

      response = post "#{config.url}/api/requests", payload
    end

    response.parsed
  end

  # Create Request Deploy if does not exist or existing active deploy is different
  def create_deploy(request_info, deploy_info)
    deploy_payload = {
      requestId: request_info[:request][:id],
      id: 1,
      containerInfo: {
          type: 'DOCKER',
          docker: {
            image: 'debian:latest'
          }
      },
      resources: {
        cpus: 0.1,
        memoryMb: 128,
        numPorts: 0
      },
      skipHealthchecksOnDeploy: false
    }.deep_merge(deploy_info)

    # Check for existing active deploy
    active_deploy = false
    if request_info[:activeDeploy]

      # Check if we don't need new deploy (check current active deploy settings)
      active_deploy = true
      diff = request_info[:activeDeploy].deep_diff(deploy_payload)
      diff.each_pair_recursively do |keys, value_diff|
        next if keys[0] == :id # We don't care about Deploy ID
        next unless value_diff[1] # We don't care about options we didn't specified ourselves

        active_deploy = false
        deploy_payload[:id] = request_info[:activeDeploy][:id].to_i + 1
        break
      end
    end

    # New deploy if necessary
    unless active_deploy
      payload = { deploy: deploy_payload }
      post "#{config.url}/api/deploys", payload
    end

    nil
  end

  # Run ONE_OFF request
  def run_request(request_id, arguments = nil)
    # @warning Request is not JSON formatted! Arguments must be a string with content type: plain/text.
    # @see https://github.com/HubSpot/Singularity/blob/8a9ccfc259e87d7857665020b0eccb193be58b7b/SingularityService/src/main/java/com/hubspot/singularity/resources/RequestResource.java#L151
    begin
      options = { content_type: :text, accept: :json }
      RestClient.post("#{config.url}/api/requests/request/" + Rack::Utils.escape(request_id) + "/run", arguments, options, &method(:request_block))
    rescue RestClient::Exception => e
      raise e unless e.response.code == 409 # Conflict
    end

    nil
  end

  # ----------------------------------------------------------------------------

  # Performs basic HTTP GET request
  def get(url, options = {})
    options.merge!({ accept: :json })
    RestClient.get(url, options, &method(:request_block))
  end

  # Performs HTTP POST request
  def post(url, payload, options = {})
    options.merge!({ content_type: :json, accept: :json })
    RestClient.post(url, payload.to_json, options, &method(:request_block))
  end

  # Handles response
  def request_block(response, request, result, &block)

    # Extend with parsing helper
    response.define_singleton_method :parsed do
      unless response.instance_variable_defined? :@parsed
        response.instance_variable_set(:@parsed, JSON.parse(response, symbolize_names: true))
      end

      response.instance_variable_get :@parsed
    end

    response.return!(request, result, &block)
  end

end