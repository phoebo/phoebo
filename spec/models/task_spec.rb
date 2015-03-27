require 'rails_helper'

RSpec.describe Task, type: :model do

  describe '.valid_next_state?' do
    it ':fresh => :scheduled_request is valid' do
      expect(described_class.valid_next_state?(:fresh, :scheduled_request)).to be true
    end

    it ':scheduled_request => :fresh is NOT valid' do
      expect(described_class.valid_next_state?(:scheduled_request, :fresh)).to be false
    end

    it ':fresh => :fresh is NOT valid' do
      expect(described_class.valid_next_state?(:fresh, :fresh)).to be false
    end

    it 'accepts index too' do
      expect(described_class.valid_next_state?(0, :scheduled_request)).to be true
    end
  end

  describe '.valid_prev_states' do
    it ':fresh returns empty array' do
      expect(described_class.valid_prev_states :fresh).to eq([])
    end

    it ':requested' do
      expect(described_class.valid_prev_states :requested).to eq([ :fresh, :scheduled_request, :requesting ])
    end

    it ':request_failed' do
      expect(described_class.valid_prev_states :request_failed).to eq([ :fresh, :scheduled_request, :requesting ])
    end
  end

  describe '.valid_prev_states(state).for_db' do
    it 'translates states' do
      expect(described_class.valid_prev_states(:request_failed).for_db) \
          .to eq([
            described_class.states[:fresh],
            described_class.states[:scheduled_request],
            described_class.states[:requesting]
          ])
    end
  end

  describe '.transient_state?' do
    it ':running is a transient state' do
      expect(described_class.transient_state? :running).to be true
    end

    it ':failed is NOT a transient state' do
      expect(described_class.transient_state? :failed).to be false
    end
  end

  describe 'steady_state?' do
    it ':running is NOT a steady state' do
      expect(described_class.steady_state? :running).to be false
    end

    it ':failed is a steady state' do
      expect(described_class.steady_state? :failed).to be true
    end
  end
end
