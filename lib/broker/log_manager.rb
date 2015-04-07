class Broker
  # Holds separate logs for all the tasks
  # Note: We don't want to store them in immutable hash, because we don't
  #   want to recreate hash each time we append to some list.
  class LogManager
    def initialize
      @mutex = Mutex.new
    end

    def write(task_mesos_id, output)
      @mutex.synchronize do
        list = nil

        if instance_variable_defined?(var = var_name(task_mesos_id).to_sym)
          list = instance_variable_get(var)
          list = list.cons(output)
        else
          list = Hamster.list(output)
        end

        instance_variable_set(var, list)
      end
    end

    def log(task_mesos_id)
      instance_variable_get(var_name(task_mesos_id)) rescue nil
    end

    private

    def var_name(task_mesos_id)
      "@_#{Digest::MD5.hexdigest(task_mesos_id)}"
    end
  end
end