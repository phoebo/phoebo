class LoginController < ApplicationController
  before_filter :authenticate_user!, except: [:new, :callback, :auth, :destroy]
  skip_filter :check_setup

  def new
  end

  def auth
    redirect_to client.auth_code.authorize_url({
      redirect_uri: login_callback_url
    })
  end

  def callback
    token = client.auth_code.get_token(params[:code], redirect_uri: login_callback_url).token

    # Fetch user info
    user_profile = GitlabConnector.new(token).current_user

    # Clear up unnecessary keys (including private_token, we will use strictly oauth token)
    allowed_keys = [:name, :username, :id, :avatar_url, :is_admin, :email]
    user_profile.keep_if { |key, _| allowed_keys.include? key }

    # Add OAuth token
    user_profile[:oauth_token] = token

    if user_profile && sign_in(user_profile)
      redirect_to root_path
    else
      @error = 'Invalid credentials'
      render :new
    end
  end

  def destroy
    sign_out
    redirect_to login_path
  end

  protected

  def client
    @client ||= ::OAuth2::Client.new(
      Rails.configuration.x.gitlab_server.app_id,
      Rails.configuration.x.gitlab_server.app_secret,
      {
        site: Rails.configuration.x.gitlab_server.url,
        authorize_url: 'oauth/authorize',
        token_url: 'oauth/token'
      }
    )
  end
end