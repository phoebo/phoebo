class HelpController < ApplicationController
  skip_filter :check_config
  skip_filter :check_setup

  def configuration
    @sample_config = File.read("#{Rails.root}/config/application.yml.example")
    render layout: 'simple'
  end
end
