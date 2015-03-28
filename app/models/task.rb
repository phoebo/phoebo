# Task model
#
# State rules:
#   Task is considered in steady state if it doesn't change it's state without user action
#   Task is in transient state if it's not in steady state
#   All error states are steady states
class Task < ActiveRecord::Base
  belongs_to :build_request

  enum kind: [ :oneoff, :service ]

  STEADY_STATE_THRESHOLD = 100
  ERROR_STATE_THRESHOLD  = 100 + STEADY_STATE_THRESHOLD

  enum state: {
    # Freshly created task (awaiting execution by user)
    fresh:              0 + STEADY_STATE_THRESHOLD,

    # Task is scheduled for async execution by ActiveJob
    scheduled_request:  1,

    # Task is being requested to Singularity (async job started)
    requesting:         2,

    # Task has been successfully sent to Singularity (async job succeeded)
    requested:          3,

    # Error when sending task to Singularity (async job failed)
    request_failed:     3 + ERROR_STATE_THRESHOLD,

    # Task has been launched by Singularity
    launched:           4,

    # Task is marked as running by Singularity
    running:            5,

    # Task has finished running and exited with success error (sent by Singularity)
    finished:           6 + STEADY_STATE_THRESHOLD,

    # Task was running but exited with error code (sent by Singularity)
    failed:             6 + ERROR_STATE_THRESHOLD,

    # Task is cheduled for deletion (awaiting ActiveJob)
    scheduled_delete:   7,

    # Task is being deleted (async job started)
    deleting:           8,

    # Task was deleted successfully (async job succeeded)
    deleted:            9,

    # Task deletion failed (async job failed)
    delete_failed:      9 + ERROR_STATE_THRESHOLD
  }

  # Compose string request id (this is used as Singularity request id)
  def request_id
    "phoebo-#{self.id}"
  end

  class << self
    # Returns TRUE if state is a transient state
    def transient_state?(state)
      !steady_state? state
    end

    # Returns TRUE if state is a steady state
    def steady_state?(state)
      states[state] >= STEADY_STATE_THRESHOLD
    end

    # Returns TRUE if state is an error state
    def error_state?(state)
      states[state] >= ERROR_STATE_THRESHOLD
    end

    def valid_next_state?(prev_state, new_state)
      normalize_state(prev_state) < normalize_state(new_state)
    end

    # Returns array of all possible states preceeding given state
    def valid_prev_states(state)
      normalized_state = normalize_state(state)
      prev = states.select do |_, v|
        normalize_state(v) < normalized_state
      end

      prev_keys = prev.symbolize_keys.keys

      # Define translation method (sym => integer)
      prev_keys.define_singleton_method :for_db do
        prev_keys.map { |v| Task.states[v] }
      end

      prev_keys
    end

    private

    # Returns normalized state index
    def normalize_state(state)
      val = state.is_a?(Integer) ? state : states[state]

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
