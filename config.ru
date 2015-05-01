# This file is used by Rack-based servers to start the application.

require ::File.expand_path('../config/environment', __FILE__)

# Trigger on_rackup handler
Rails.application.on_rackup

# Pass application
run Rails.application
