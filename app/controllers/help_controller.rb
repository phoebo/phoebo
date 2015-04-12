class HelpController < ApplicationController
  skip_filter :check_config

  def invalid_config
    if self.class.valid_config?
      redirect_to root_path
    else
      render layout: 'simple'
    end
  end

  def no_projects
  	# We invalidate gitlab cache
    if current_user && !current_user.gitlab.user_projects.empty?
      redirect_to root_path
    end
  end
end
