require 'rails_helper'
require File.expand_path('../../../../lib/broker.rb', __FILE__)

RSpec.describe Broker::Task do
  it "has a valid factory" do
    expect(build(:broker_task)).to be_a(Broker::Task)
    expect(build(:broker_task, :running).run_id).not_to be_nil
  end

  describe '.valid_next_state?' do
    it ':fresh => :requested is valid' do
      expect(described_class.valid_next_state?(:fresh, :requested)).to be true
    end

    it ':requested => :fresh is NOT valid' do
      expect(described_class.valid_next_state?(:requested, :fresh)).to be false
    end

    it ':fresh => :fresh is NOT valid' do
      expect(described_class.valid_next_state?(:fresh, :fresh)).to be false
    end
  end

  describe '.valid_prev_states' do
    it ':fresh returns empty array' do
      expect(described_class.valid_prev_states :fresh).to eq([])
    end

    it ':requested' do
      expect(described_class.valid_prev_states :requested).to eq([ :fresh ])
    end

    it ':deploy_started' do
      expect(described_class.valid_prev_states :deploy_started).to eq([ :fresh, :requested ])
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