class ApplicationController < ActionController::Base
  rescue_from GitlabConnector::UnauthorizedError, with: :invalid_token

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  before_filter :default_headers
  before_filter :check_config

  helper_method :current_user

  private

  def with_redis(&block)
    Sidekiq.redis(&block)
  end

  def gitlab
    @gitlab_connector ||= GitlabConnector.new(current_user.oauth_token)
  end

  def current_user
    @current_user ||= (session[:current_user] ? User.new(session[:current_user]) : nil)
  end

  def sign_in(user)
    session[:current_user] = user
  end

  def sign_out
    reset_session
  end

  def authenticate_user!
    unless current_user
      redirect_to login_path
      return
    end
  end

  def invalid_token
    reset_session
    redirect_to :root
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
