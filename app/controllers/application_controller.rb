class ApplicationController < ActionController::Base
  rescue_from GitlabConnector::UnauthorizedError, with: :invalid_token

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  before_filter :default_headers
  before_filter :check_config
  before_filter :check_setup

  helper_method :current_user

  def current_user
    @current_user ||= (session[:user_data] ? User.new(session[:user_data]) : nil)
  end

  def broker
    Rails.application.broker
  end

  private

  def gitlab
    current_user ? current_user.gitlab : nil
  end

  def sign_in(user)
    reset_session
    session[:user_data] = user
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
    if Phoebo.config.errors?
      @errors = Phoebo.config.errors
      render 'invalid_config', layout: 'simple'
    end
  end

  def check_setup
    unless Rails.application.setup_completed?
      if request.format == 'application/json'
        head :service_unavailable
      else
        redirect_to setup_path
      end
    end
  end
end
