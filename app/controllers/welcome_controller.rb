class WelcomeController < ApplicationController
  def index
  end

  def run
    # TODO
    redirect_to action: 'index'
  end
end
