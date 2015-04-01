require 'rails_helper'
require 'support/redis.rb'

RSpec.describe SetupJob do
  include_context 'redis'

  subject { described_class.new }
  let(:args) { [ 'http://127.0.0.1:3000/webhook' ] }

  describe '.update_state' do
    it 'sets state and publishes it' do
      payload = { state: described_class::STATE_FAILED, state_message: "Some error" }.to_json

      expect(redis).to receive(:set).with(
       described_class::REDIS_KEY_STATE,
       payload
      )

      expect(redis).to receive(:publish).with(
       described_class::REDIS_KEY_UPDATES,
       payload
      )

      described_class.new.send(:update_state, described_class::STATE_FAILED, "Some error")
    end
  end

  describe '.perform' do

    context 'success' do
      it 'sends state updates' do
        expect(subject).to receive(:update_state).with(described_class::STATE_WORKING)
        expect(subject).to receive(:update_state).with(described_class::STATE_DONE)
        allow(subject).to receive(:setup).with(*args).and_return(nil)
        subject.perform(*args)
      end
    end
    context 'failure' do
      it 'sends state updates with error message' do
        expect(subject).to receive(:update_state).with(described_class::STATE_WORKING)
        expect(subject).to receive(:update_state).with(described_class::STATE_FAILED, "My error message")
        allow(subject).to receive(:setup).with(*args) { raise "My error message" }
        subject.perform(*args)
      end
    end
  end

  # describe '.setup' do
  #   it 'doesn\'t fail' do
  #     subject.send(:setup, *args)
  #   end
  # end
end
