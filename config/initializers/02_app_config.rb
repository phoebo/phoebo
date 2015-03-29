require 'yaml'

module Phoebo
  class Application
    def load_app_config(file_path)
      app_config = YAML::load(File.open(file_path))
      stack = Array.new
      stack.push([app_config[Rails.env], Rails.configuration.x])

      while !stack.empty?
        source, target = stack.pop
        source.each do |key, value|
          if value.respond_to? :each
            stack.push [value, target.send(key)]
          else
            target.send("#{key}=", value)
          end
        end
      end

      # Remove trailing slashes in URLs
      Rails.configuration.x.gitlab_server.url.chomp!('/')
      Rails.configuration.x.singularity.url.chomp!('/')

      # Apply default URL options
      Rails.configuration.x.url.each do |k, v|
        routes.default_url_options[k] = v
      end
    end
  end
end

Phoebo::Application.load_app_config("#{Rails.root}/config/application.yml")

