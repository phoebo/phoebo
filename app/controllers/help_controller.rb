class HelpController < ApplicationController
  skip_filter :check_config

  def invalid_config
    if self.class.valid_config?
      redirect_to root_path
    else
      render layout: 'simple'
    end
  end
end
