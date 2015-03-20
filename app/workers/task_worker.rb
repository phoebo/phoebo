class TaskWorker < SingularityWorker

  def perform(webhook_url)
    Sidekiq.redis do |redis|
      redis.append "log", "Launching ...\n"
      redis.publish "log", "Launching ..."
    end

    @helpers ||= Helpers.new(self)

    # TODO: we might want to do this just the first time
    #   (but careful with concurrency)
    @helpers.install_webhook(webhook_url)

    request_info = @helpers.create_request("imagebuilder")
    deploy_info = {
      command: 'phoebo',
      containerInfo: {
        docker: {
          image: 'phoebo/phoebo:latest',
          privileged: true
        }
      }
    }

    @helpers.create_deploy(request_info, deploy_info)
    @helpers.run_request("imagebuilder", "--help")

    Sidekiq.redis do |redis|
      redis.append "log", "Launched :)\n"
      redis.publish "log", "Launched :)"
    end
  end

  class Helpers < SingularityWorker::Helpers
    def install_webhook(url)
      payload = {
        id: 'phoebo',
        uri: url,
        type: :TASK
      }

      response = RestClient.get "#{config.api_url}/webhooks", accept: :json
      webhook_info = JSON.parse(response.to_str)
      webhook_info.select! { |v| v['id'] == payload[:id] }

      if webhook_info.size == 0 || webhook_info[0].deep_symbolize_keys.deep_diff(payload).size > 0
        RestClient.delete "#{config.api_url}/webhooks/" + Rack::Utils.escape(payload[:id]), accept: :json
      else
        return
      end

      RestClient.post "#{config.api_url}/webhooks", payload.to_json, content_type: :json, accept: :json
    end

    def create_request(request_id, is_service = false)
      url = "#{config.api_url}/requests/request/" + Rack::Utils.escape(request_id)
      begin
        response = RestClient.get url, accept: :json
      rescue RestClient::Exception => e
        raise e unless e.response.code == 404

        payload = {
          id: request_id,
          daemon: is_service
        }

        response = RestClient.post "#{config.api_url}/requests", payload.to_json, content_type: :json, accept: :json
      end

      JSON.parse(response.to_str)
    end

    def create_deploy(request_info, deploy_info)
      deploy_payload = {
        requestId: request_info['request']['id'],
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
      if request_info['activeDeploy']

        # Check if we don't need new deploy (check current active deploy settings)
        active_deploy = true
        diff = request_info['activeDeploy'].deep_symbolize_keys.deep_diff(deploy_payload)
        diff.each_pair_recursively do |keys, value_diff|
          next if keys[0] == :id # We don't care about Deploy ID
          next unless value_diff[1] # We don't care about options we didn't specified ourselves

          puts keys.inspect
          puts value_diff.inspect

          active_deploy = false
          deploy_payload[:id] = request_info['activeDeploy']['id'].to_i + 1
          break
        end
      end

      # New deploy if necessary
      unless active_deploy
        payload = { deploy: deploy_payload }
        RestClient.post "#{config.api_url}/deploys", payload.to_json, content_type: :json, accept: :json
      end
    end

    def run_request(request_id, arguments)
      # @warning Request is not JSON formatted! Arguments must be a string with content type: plain/text.
      # @see https://github.com/HubSpot/Singularity/blob/8a9ccfc259e87d7857665020b0eccb193be58b7b/SingularityService/src/main/java/com/hubspot/singularity/resources/RequestResource.java#L151
      RestClient.post "#{config.api_url}/requests/request/" + Rack::Utils.escape(request_id) + "/run", arguments, content_type: :text, accept: :json
    end
  end

end