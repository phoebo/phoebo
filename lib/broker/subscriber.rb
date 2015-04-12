class Broker
  class Subscriber
    EVENTS = [ :task_update, :task_output ]
    def initialize(broker)
      @broker = broker

      EVENTS.each do |event|
        instance_variable_set("@#{event}_mutex", Mutex.new)
        instance_variable_set("@#{event}_handler", nil)
        instance_variable_set("@#{event}_filter", nil)
        instance_variable_set("@#{event}_filter_mutex", Mutex.new)
      end
    end

    def subscribe_for(event, filter = {})

      raise "Invalid event type #{event.inspect}" \
        unless EVENTS.include?(event)

      begin
        handler = instance_variable_get("@#{event}_handler")
        raise unless handler
      rescue
        raise "No handler registered for #{event.inspect}"
      end

      # Prepare filter
      filter.each do |key, value|
        unless value.is_a?(Array)
          filter[key] = [ value ]
        end
      end

      # Update filter
      new_filter = nil
      instance_variable_get("@#{event}_filter_mutex").synchronize do
        new_filter = instance_variable_get("@#{event}_filter") || Hamster.hash

        filter.each do |key, value|
          new_filter = new_filter.store(key,
            new_filter.fetch(key, nil).nil? \
              ? Hamster.vector(*value) \
              : new_filter.fetch(key) + value
          )
        end

        instance_variable_set("@#{event}_filter", new_filter)
      end

      # Send initial data
      if event == :task_update
        @task_update_mutex.synchronize do
          @broker.tasks.each do |_, task|
            if self.class.matching_task?(task, Hamster.hash(filter))
              handler.call(task, nil, nil)
            end
          end
        end
      elsif event == :task_output
        @task_output_mutex.synchronize do
          @broker.tasks.each do |_, task|
            if self.class.matching_task?(task, Hamster.hash(filter))
              if log = @broker.task_log(task.id)
                handler.call(task, log.reverse.each)
              end
            end
          end
        end
      end

      new_filter
    end

    def unsubscribe_from(event, filter = {})
      new_filter = nil

      # Update filter
      instance_variable_get("@#{event}_filter_mutex").synchronize do
        new_filter = instance_variable_get("@#{event}_filter")

        unless new_filter.nil?
          filter.each do |key, value|
            if key_filter = new_filter.fetch(key, nil)
              key_filter = key_filter.delete(value)

              if key_filter.empty?
                new_filter = new_filter.delete(key)
              else
                new_filter = new_filter.store(key, key_filter)
              end
            end
          end

          new_filter = nil if new_filter.empty?
          instance_variable_set("@#{event}_filter", new_filter)
        end
      end

      new_filter
    end

    def process(event, task, *args)
      handler   = instance_variable_get("@#{event}_handler")
      filter = instance_variable_get("@#{event}_filter")

      if !handler.nil? && self.class.matching_task?(task, filter)
        instance_variable_get("@#{event}_mutex").synchronize do
          handler.call(task, *args)
        end
      end
    end

    def handle(event, &block)
      raise "Missing block" unless block_given?

      if instance_variable_defined?(sym = "@#{event}_handler")
        instance_variable_set(sym, block)
      else
        raise "Invalid event type #{event.inspect}."
      end

      self
    end

    # Detaches this subscriber from broker
    def detach
      @broker.remove_subscriber(self)
    end

    private

    def self.matching_task?(task_info, filter)
      return false unless filter

      filter.each do |key, values|
        # Hamster::Vector
        if values.rindex(task_info.send(key)).nil?
          return false
        end
      end

      true
    end
  end
end