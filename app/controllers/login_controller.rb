class LoginController < ApplicationController
  before_filter :authenticate_user!, except: [:new, :callback, :auth, :destroy]
  skip_filter :check_setup

  def new
    render layout: 'simple'
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
    user_profile.keep_if { |key, _| User::DEFAULT_ATTRIBUTES.has_key? key }

    # Add OAuth token
    user_profile[:oauth_token] = token

    # Add profile url
    user_profile[:profile_url] = Phoebo.config.gitlab_server.url + "/u/#{Rack::Utils.escape(user_profile[:username])}"

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
      Phoebo.config.gitlab_server.app_id,
      Phoebo.config.gitlab_server.app_secret,
      {
        site: Phoebo.config.gitlab_server.url,
        authorize_url: 'oauth/authorize',
        token_url: 'oauth/token'
      }
    )
  end
end