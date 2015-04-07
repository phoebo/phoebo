require File.join(Rails.root, "lib", "broker.rb")

module Phoebo
  class Application < Rails::Application
    attr_accessor :broker
  end
end