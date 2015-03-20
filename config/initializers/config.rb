Rails.application.config.redis = OpenStruct.new
Rails.application.config.redis.host = '10.10.3.230'

Rails.application.config.singularity = OpenStruct.new
Rails.application.config.singularity.api_url = 'http://mesos.local:7099/singularity/api'