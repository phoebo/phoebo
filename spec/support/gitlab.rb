RSpec.shared_context 'gitlab' do

  let(:gitlab) do
    # Mock user's GitlabConnector
    obj = GitlabConnector.new('2EAAAADAQABAAABAQDEvUKbIyAdN5adpI9')
    obj.public_methods(false).each do |method_name|
      case

      # Passing cache_key queries
      when method_name[0...14] == 'cache_key_for_'
        next

      # Empty implementation for purge_cache
      when method_name[0...13] == 'purge_cached_'
        allow(obj).to receive(method_name)

      # Redirecting cached versions to uncached versions
      when method_name[0...7] == 'cached_'
        allow(obj).to receive(method_name) do |*args|
          obj.send(method_name[7..-1].to_sym, *args)
        end

      # All other methods has be defined
      #   we do this for strict method call checking
      #   (because we cant use instance double because we are using some of the methods)
      else
        allow(obj).to receive(method_name) do |*args|
          RSpec::Mocks::ErrorGenerator.new(obj, 'User GitlabConnector').raise_unexpected_message_error(method_name, *args)
        end
      end
    end

    # Define some user projects
    cached_projects = nil
    allow(obj).to receive(:user_projects) do
      cached_projects ||= build_list(:gitlab_project, 5).to_h_by(:id)
    end

    allow(obj).to receive(:project) do |project_id|
      obj.user_projects[project_id]
    end

    obj
  end

end