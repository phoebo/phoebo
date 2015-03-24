class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  before_filter :default_headers
  before_filter :check_config

  private

  def with_redis(&block)
    Sidekiq.redis(&block)
  end

  def default_headers
    headers['X-Frame-Options'] = 'DENY'
    headers['X-XSS-Protection'] = '1; mode=block'
  end

  def check_config
    redirect_to help_invalid_config_path unless self.class.valid_config?
  end

  def self.valid_config?
    if @valid_config.nil?
      server = Rails.configuration.x.gitlab_server

      error = server.blank? || server.url.blank? || server.app_id.blank? || server.app_secret.blank?
      @valid_config = !error
    end

    @valid_config
  end

end
