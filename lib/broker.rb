# Thread-safe message brooker for publishing state changes to subscribed listeners
class Broker
  autoload :Immutable,               'broker/immutable'
  autoload :ImmutableTransformation, 'broker/immutable_transformation'
  autoload :LogManager,              'broker/log_manager'
  autoload :Subscriber,              'broker/subscriber'
  autoload :SingularityTaskLoader,   'broker/singularity_task_loader'
  autoload :Task,                    'broker/task'

  def initialize(tasks = [])
    @next_task_id = 1
    @next_task_id_mutex = Mutex.new

    # Initial data
    run_ids = {}
    task_hash = {}
    tasks.each do |task|
      task.id = @next_task_id
      @next_task_id += 1
      task.freeze

      if task.run_id
        run_ids[task.run_id] = task.id
      end

      task_hash[task.id] = task
    end

    @subscribers       = Hamster.vector
    @subscribers_mutex = Mutex.new

    @tasks       = Hamster.hash(task_hash)
    @tasks_mutex = Mutex.new

    @run_ids       = Hamster.hash(run_ids)
    @run_ids_mutex = Mutex.new

    @log_manager = LogManager.new
  end

  # ----------------------------------------------------------------------------

  attr_accessor :tasks

  # Returns task by ID
  def task(task_id)
    @tasks.key?(task_id) ? @tasks.get(task_id) : nil
  end

  # Alias
  def new_task(&block)
    update_task(nil, &block)
  end

  # Updates task info by executing given block
  def update_task(task_id, &block)
    old_task = nil
    new_task = nil
    diff     = nil

    # We need lock on write to prevent race conditions
    # Example:
    #   Thread 1: updates task to state :launched
    #   Thread 2: updates task to state :running (in between and finishes before Thread 1)
    #   This may happend because we can't be sure which notification comes first (webhook),
    #   we are checking that the state is always succeeeded by higher state, but
    #   the condition itself needs to happen in thread safe environment otherwise it might fail.
    begin
      @tasks_mutex.lock

      # Retrieve latest task info or create new
      if @tasks.key?(task_id)
        task = old_task = @tasks.get(task_id)
      else
        task = Task.new
        task.id = task_id || new_task_id
      end

      # Transformation
      transformation = task.transform(&block)
      diff           = transformation.diff
      new_task       = transformation.apply

      # Save updated task info (does nothing if nothing is changed)
      @tasks = @tasks.store(task.id, new_task)
    ensure
      @tasks_mutex.unlock
    end

    # Broadcast the change
    unless new_task.equal?(old_task)
      broadcast :task_update, new_task, old_task, diff
    end

    # Maintain run_id <=> task_id translation table
    if diff.key?(:run_id)

      # We are checking if there isn't some logged output for that mesos id.
      #  It is unlikely but we can have mesos id later than the output is began
      #  to be sent so we might lose first few lines.
      if log = @log_manager.log(new_task.run_id)
        broadcast :task_output, new_task.id, log.reverse.each
      end

      @run_ids_mutex.synchronize do
        @run_ids = @run_ids.put(new_task.run_id, new_task.id)
      end
    end

    # Return new task
    new_task
  end

  def remove_task(task_id)
    if task = task(task_id)
      update_task(task.id) do |task|
        task.state = :deleted
      end

      # TODO: remove task log too
      @tasks_mutex.synchronize { @tasks = @tasks.delete(task.id) }
    end

    task
  end

  # ----------------------------------------------------------------------------

  # Writes log
  def log_task_output(task_run_id, output)
    @log_manager.write(task_run_id, output)

    if task_id = @run_ids.get(task_run_id)
      broadcast :task_output, task(task_id), output
    end
  end

  # Returns log for task with given ID
  def task_log(task_id)
    task = self.task(task_id)
    if task && task.run_id && !task.run_id.empty?
      @log_manager.log(task.run_id)
    else
      nil
    end
  end

  # ----------------------------------------------------------------------------

  # Register new subscriber
  def new_subscriber
    s = Subscriber.new(self)

    @subscribers_mutex.synchronize do
      @subscribers = @subscribers.add(s)
    end

    s
  end

  # Remove subscriber
  # @internal
  def remove_subscriber(subscriber)
    @subscribers_mutex.synchronize do
      @subscribers = @subscribers.delete(subscriber)
    end

    subscriber
  end

  # Broadcast message to all available subscribers in thread-safe fashion
  def broadcast(event, *args)
    # if event == :task_update
    #   puts "TASK_UPDATE #{args[0].run_id} (#{args[0].id}): " + (args[2].empty? ? args[0].inspect : args[2].inspect)
    # else
    #   # puts "TASK_OUTPUT #{args[0].run_id} (#{args[0].id}): #{args[1]}"
    # end

    subscribers = @subscribers
    subscribers.each do |subscriber|
      subscriber.process(event, *args)
    end
  end

  private :broadcast

  private

  def new_task_id
    task_id = nil
    @next_task_id_mutex.synchronize do
      task_id = @next_task_id
      @next_task_id += 1
    end

    task_id
  end
end