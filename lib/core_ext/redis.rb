class Redis
  class << self
    def composite_key(*args)
      args.collect do |arg|
        arg.to_s.gsub(/\\/, '\\\\\\\\').gsub(/\//, '\\\\/')
      end.join('/')
    end

    def key_for_task_updates(ids)
      args = []
      args << 'project' << (ids[:project_id] || '-')
      args << 'build_request' << (ids[:build_request_id] || '-')
      args << 'task' << (ids[:task_id] || '-')
      args << 'updates'

      composite_key(*args)
    end

    def parse_key_for_task_updates(str)
      if m = str.match(/^project\/(-|[0-9]+)\/build_request\/(-|[0-9]+)\/task\/([0-9]+)\/updates$/)
        ids = { }
        ids[:project_id] = m[1].to_i unless m[1] == '-'
        ids[:build_request_id] = m[2].to_i unless m[2] == '-'
        ids[:task_id] = m[3].to_i
        ids
      end
    end

    def key_for_mesos_log(mesos_task_id)
      composite_key('mesos_task', mesos_task_id, 'log')
    end

    def key_for_mesos_log_updates(mesos_task_id)
      composite_key('mesos_task', mesos_task_id, 'log_updates')
    end

    def parse_key_for_mesos_log_updates(str)
      if m = str.match(/^mesos_task\/(.+)\/log_updates$/)
        m[1]
      end
    end
  end
end

# Use Sidekiq connection pool
def with_redis(&block)
  Sidekiq.redis(&block)
end