class TaskSchedulerJob < ActiveJob::Base
  queue_as :default

  def perform(task, webhook_url)

    # Set task state as REQUESTING
    # Stop if task was in the invalid state
    unless update_task_state(task.id, :requesting) > 0
      return
    end

    install_webhook(webhook_url)
    request_info = create_request(task.id)

    # deploy_info = {
    #   command: 'phoebo',
    #   containerInfo: {
    #     docker: {
    #       image: 'phoebo/phoebo:latest',
    #       privileged: true
    #     }
    #   }
    # }

    # create_deploy(request_info, deploy_info)
    # run_request(task.id, "--help")

    deploy_info = {
      command: '/bin/bash',
      # arguments: ['-c', 'export'],
      arguments: ['-c', 'for INDEX in 1 2 3 4 5 6 7 8 9 10; do echo "$INDEX"; sleep 1; done'],
      # arguments: ['-c', 'while sleep 2; do date -u +%T; done'],
      containerInfo: {
        docker: {
          image: 'debian:latest'
        }
      }
    }

    create_deploy(request_info, deploy_info)
    run_request(task.id)

    # Update task state to REQUESTED
    update_task_state(task.id, :requested)
  end

  # ----------------------------------------------------------------------------
  private

  def update_task_state(task_id, new_state)
    num_affected = Task.where('id = ?', task_id)
        .where('state < ?', Task.states[new_state])
        .update_all(
          state: Task.states[new_state]
        )

    if num_affected > 0
      Sidekiq.redis do |redis|
        updates_key = Redis.composite_key('task', task_id, 'updates')
        redis.publish updates_key, { state: new_state }.to_json
      end
    end

    num_affected
  end

  # Singularity config
  def config
    Rails.configuration.singularity
  end

  # Install webhook if necessary
  def install_webhook(url)
    payload = {
      id: 'phoebo',
      uri: url,
      type: :TASK
    }

    response = RestClient.get "#{config.api_url}/webhooks", accept: :json
    webhook_info = JSON.parse(response.to_str, symbolize_names: true)
    webhook_info.select! { |v| v[:id] == payload[:id] }

    if webhook_info.size == 0 || webhook_info[0].deep_diff(payload).size > 0
      RestClient.delete "#{config.api_url}/webhooks/" + Rack::Utils.escape(payload[:id]), accept: :json
    else
      return
    end

    RestClient.post "#{config.api_url}/webhooks", payload.to_json, content_type: :json, accept: :json
  end

  # Create Singularity request if does not exist
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

    JSON.parse(response.to_str, symbolize_names: true)
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
      RestClient.post "#{config.api_url}/deploys", payload.to_json, content_type: :json, accept: :json
    end
  end

  # Run ONE_OFF request
  def run_request(request_id, arguments = nil)
    # @warning Request is not JSON formatted! Arguments must be a string with content type: plain/text.
    # @see https://github.com/HubSpot/Singularity/blob/8a9ccfc259e87d7857665020b0eccb193be58b7b/SingularityService/src/main/java/com/hubspot/singularity/resources/RequestResource.java#L151
    begin
      RestClient.post "#{config.api_url}/requests/request/" + Rack::Utils.escape(request_id) + "/run", arguments, content_type: :text, accept: :json
    rescue RestClient::Exception => e
      raise e unless e.response.code == 409 # Conflict
    end
  end

end
