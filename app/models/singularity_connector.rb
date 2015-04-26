class SingularityConnector

  attr_reader :config

  # Constructor
  def initialize(config = nil)
    @config = config || Phoebo.config.singularity
  end

  # Install webhook if necessary
  def install_webhook(id, url, type)
    payload = {
      id: id,
      uri: url,
      type: type
    }

    response = get "#{config.url}/api/webhooks"
    webhook_info = response.parsed
    webhook_info.select! { |v| v[:id] == payload[:id] }

    if webhook_info.size == 0 || webhook_info[0].deep_diff(payload).size > 0
      remove_webhook(payload[:id])
    else
      return
    end

    post "#{config.url}/api/webhooks", payload
  end

  def remove_webhook(id)
    RestClient.delete("#{config.url}/api/webhooks/" + Rack::Utils.escape(id), accept: :json, &method(:request_block))
  end

  def requests
    get("#{config.url}/api/requests").parsed
  end

  def request_deploy(request_id, deploy_id)
    get("#{config.url}/api/history/request/" + Rack::Utils.escape(request_id) + "/deploy/" + Rack::Utils.escape(deploy_id)).parsed
  end

  def request_tasks(request_id, active = false)
    get("#{config.url}/api/history/request/" + Rack::Utils.escape(request_id) + "/tasks" + (active ? '/active' : '')).parsed
  end

  def task(task_id)
    get("#{config.url}/api/history/task/" + Rack::Utils.escape(task_id)).parsed
  end

  # Create Singularity request
  def create_request(request_id_hint = nil, is_service = false)
    i = 1
    begin
      payload = {
        id: 'phoebo-' + Time.now.to_i.to_s + "-#{i}",
        daemon: is_service
      }

      payload[:id] += '-' + request_id_hint if request_id_hint

      response = post("#{config.url}/api/requests", payload).parsed

      # Try again if it is some existing request (ID collision)
      if response[:request][:requestDeployState]
        raise RestClient::BadRequest
      end

    # Try again if request fails because we are trying to change some existing
    # request in way we are not allowed to
    rescue RestClient::BadRequest
      i += 1
      retry if i < 5
      return nil
    end

    response
  end

  def remove_request(request_id)
    RestClient.delete("#{config.url}/api/requests/request/" + Rack::Utils.escape(request_id), accept: :json, &method(:request_block))
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
    if active_deploy
      false
    else
      payload = { deploy: deploy_payload }
      post("#{config.url}/api/deploys", payload)
      true
    end
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

    if response.code >= 400
      puts "#{request.method.upcase} #{request.url} returned #{response.code}: #{response}"
    end

    response.return!(request, result, &block)
  end

  # ----------------------------------------------------------------------------

  module Helpers
    # Return formatted Request ID for Singularity
    def request_id(ids)
      str  = 'phoebo'
      str += "-p#{ids[:project_id]}" if ids[:project_id]
      str += "-b#{ids[:build_request_id]}" if ids[:build_request_id]
      str += "-t#{ids[:task_id]}" if ids[:task_id]
      str
    end

    # Parse Task ID from Singularity Request ID
    def parse_request_id(str)
      if m = str.match(/^phoebo(-p([0-9]+)-b([0-9]+))?-t([0-9]+)$/)
        parsed = { }
        parsed[:project_id] = m[2].to_i if m[2]
        parsed[:build_request_id] = m[3].to_i if m[3]
        parsed[:task_id] = m[4].to_i

        return parsed
      end
    end
  end

  include Helpers
  extend Helpers

end