class Broker
  class Task
    include Immutable

    STEADY_STATE_THRESHOLD = 100
    ERROR_STATE_THRESHOLD  = 100 + STEADY_STATE_THRESHOLD

    STATES = {
      # Freshly created task (awaiting execution by user)
      fresh:              0,

      # Task has been successfully sent to Singularity (async job succeeded)
      requested:          1,

      # Error when sending task to Singularity (async job failed)
      request_failed:     1 + ERROR_STATE_THRESHOLD,

      # Task is being deployed by Singularity
      deploying:          2,

      # Task is marked as deployed by Singularity
      deployed:           3,

      # Task deploy failed (sent by Singularity)
      deploy_failed:      3 + ERROR_STATE_THRESHOLD,

      # Task has been launched by Singularity
      launched:           4,

      # Task is marked as running by Singularity
      running:            5,

      # Task has finished running and exited with success error (sent by Singularity)
      finished:           6 + STEADY_STATE_THRESHOLD,

      # Task was running but exited with error code (sent by Singularity)
      failed:             6 + ERROR_STATE_THRESHOLD,

      # Task is being deleted (async job started)
      deleting:           7,

      # Task was deleted successfully (async job succeeded)
      deleted:            8,

      # Task deletion failed (async job failed)
      delete_failed:      8 + ERROR_STATE_THRESHOLD
    }

    # Define all states as Broker::Task::STATE_* constants
    STATES.each { |key, _| const_set("STATE_#{key.upcase}", key) }

    # --------------------------------------------------------------------------

    # Our IDs
    attr_accessor :id, :name

    # Singularity IDs
    attr_accessor :request_id, :run_id

    # Task type
    attr_accessor :daemon

    # State
    attr_reader   :state
    attr_accessor :state_message

    # Project info
    attr_reader :project_id

    # Build info
    attr_accessor :build_ref, :build_secret

    # Slave info
    attr_accessor :runner_slave_id, :runner_host

    # Run info
    attr_accessor :port_mappings

    # --------------------------------------------------------------------------

    def initialize
      @state = :fresh
    end

    def state=(new_state)
      raise "Invalid state #{new_state}" unless STATES.key?(new_state)
      @state = new_state
    end

    def project_id=(id)
      @project_id = id.to_i
    end

    def state_id
      @state ? STATES[@state] : nil
    end

    def valid_next_state?(next_state)
      self.class.valid_next_state?(@state, next_state)
    end

    def to_h
      instance_variables.collect { |var| [var[1..-1].to_sym, instance_variable_get(var)] }.to_h
    end

    def has_output?
      @has_output ? true : false
    end

    def has_output=(val)
      @has_output = val ? true : false
    end

    # --------------------------------------------------------------------------

    class << self
      # Returns TRUE if state is a transient state
      def transient_state?(state)
        !steady_state? state
      end

      # Returns TRUE if state is a steady state
      def steady_state?(state)
        STATES[state] >= STEADY_STATE_THRESHOLD
      end

      # Returns TRUE if state is an error state
      def error_state?(state)
        STATES[state] >= ERROR_STATE_THRESHOLD
      end

      def valid_next_state?(prev_state, new_state)
        normalize_state(prev_state) < normalize_state(new_state)
      end

      # Returns array of all possible states preceeding given state
      def valid_prev_states(state)
        normalized_state = normalize_state(state)
        prev = STATES.select do |_, v|
          normalize_state(v) < normalized_state && v < ERROR_STATE_THRESHOLD
        end

        prev.keys
      end

      private

      # Returns normalized state index
      def normalize_state(state)
        val = state.is_a?(Integer) ? state : STATES[state]

        case
        when val.nil?
          raise "Invalid task state #{state.inspect}"
        when val >= ERROR_STATE_THRESHOLD
          return val - ERROR_STATE_THRESHOLD
        when val >= STEADY_STATE_THRESHOLD
          return val - STEADY_STATE_THRESHOLD
        else
          return val
        end
      end
    end
  end
end

