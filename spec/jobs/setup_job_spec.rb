require 'rails_helper'

RSpec.describe SetupJob, type: :job do
  subject { described_class.new }
  let(:args) { [ 'http://127.0.0.1:3000/webhook' ] }

  describe '.update_state' do
    let(:redis) do
      redis = instance_double(Redis)
      allow_any_instance_of(Object).to receive(:with_redis).and_yield(redis)
      allow(redis).to receive(:multi).and_yield
      redis
    end

    it 'sets state and publishes it' do
      expect(redis).to receive(:set).with(
       described_class::REDIS_KEY_STATE,
       described_class::STATE_WORKING
      )

      expect(redis).to receive(:publish).with(
       described_class::REDIS_KEY_UPDATES,
       described_class::STATE_WORKING
      )

      described_class.new.send(:update_state, described_class::STATE_WORKING)
    end

    it 'deletes existing message' do
      expect(redis).to receive(:del).with(
       described_class::REDIS_KEY_MESSAGE
      )

      expect(redis).to receive(:set).with(
       described_class::REDIS_KEY_STATE,
       described_class::STATE_WORKING
      )

      expect(redis).to receive(:publish).with(
       described_class::REDIS_KEY_UPDATES,
       described_class::STATE_WORKING
      )

      described_class.new.send(:update_state, described_class::STATE_WORKING, nil)
    end

    it 'sets message' do
      expect(redis).to receive(:set).with(
       described_class::REDIS_KEY_MESSAGE,
       'Some error message'
      )

      expect(redis).to receive(:set).with(
       described_class::REDIS_KEY_STATE,
       described_class::STATE_WORKING
      )

      expect(redis).to receive(:publish).with(
       described_class::REDIS_KEY_UPDATES,
       described_class::STATE_WORKING
      )

      described_class.new.send(:update_state, described_class::STATE_WORKING, 'Some error message')
    end
  end

  describe '.perform' do

    context 'success' do
      it 'sends state updates' do
        expect(subject).to receive(:update_state).with(described_class::STATE_WORKING, nil)
        expect(subject).to receive(:update_state).with(described_class::STATE_DONE)
        allow(subject).to receive(:setup).with(*args).and_return(nil)
        subject.perform(*args)
      end
    end
    context 'failure' do
      it 'sends state updates with error message' do
        expect(subject).to receive(:update_state).with(described_class::STATE_WORKING, nil)
        expect(subject).to receive(:update_state).with(described_class::STATE_FAILED, "My error message")
        allow(subject).to receive(:setup).with(*args) { raise "My error message" }
        subject.perform(*args)
      end
    end
  end

  describe '.setup' do
    it 'doesn\'t fail' do
      subject.send(:setup, *args)
    end
  end
end
