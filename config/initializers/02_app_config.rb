require 'yaml'

module Phoebo
  class Config
    include Nested

    attr_reader :errors

    def initialize(file_path)
      begin
        app_config = YAML::load(File.open(file_path))
        @errors = load!(app_config[Rails.env], symbolize_keys: true)

      rescue Psych::SyntaxError => e
        @errors = [[nil, nil, e.message]]
      end
    end

    def errors?
      !@errors.empty?
    end

    nested(:url, :required) {
      property :protocol, default: 'http://'
      property :host, :required
      property :port, default: 80
    }

    nested(:gitlab_server, :required) {
      property :url, :url
      property :app_id, :required
      property :app_secret, :required
    }

    nested(:singularity, :required) {
      property :url, :url
    }

    nested(:redis, :required) {
      property :host, :required
    }

    nested(:logspout, :required) {
      nested(:webhook, :required) {
        property :url, :url, :required
      }
    }

    # Remove trailing slashes in URLs
    trait(:url) { |obj, key|
      obj.send(key).chomp!('/')
    }
  end

  def self.config
    @config ||= Config.new("#{Rails.root}/config/application.yml")
  end

  class Application
    def load_app_config
      # Apply default URL options
      Phoebo.config.url.each do |k, v|
        routes.default_url_options[k] = v
      end
    end
  end
end

Phoebo::Application.load_app_config if defined?(Rails::Server)
