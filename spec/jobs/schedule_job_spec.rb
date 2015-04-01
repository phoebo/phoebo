require 'rails_helper'
require 'support/redis.rb'

RSpec.describe ScheduleJob, type: :job do
  include_context 'redis'

  subject { described_class.new }

  describe '.update_state' do
    it 'updates Task and sends update to Redis' do
      # Create some task
      task = create(:task)

      # State change data
      data = {
        state: :request_failed,
        state_message: "Some error"
      }

      # Expect state notification publish
      expect(redis).to receive(:publish).with(task.updates_channel, data.to_json)

      # Expect 1 row to be changed
      expect(subject.send(:update_task, task, data)).to be 1

      # Expect task state to be changed
      task = Task.find(task.id)
      expect(task.request_failed?).to be true
    end
  end

  describe '.perform' do
    context 'success' do
      it 'sends state updates' do
        task = create(:task)
        expect(subject).to receive(:update_task).with(task, state: :requesting).and_return(1)
        expect(subject).to receive(:update_task).with(task, state: :requested).and_return(1)
        allow(subject).to receive(:schedule).with(task).and_return(nil)
        subject.perform(task)
      end
    end
    context 'failure' do
      it 'sends state updates with error message' do
        task = create(:task)
        expect(subject).to receive(:update_task).with(task, state: :requesting).and_return(1)
        expect(subject).to receive(:update_task).with(task, state: :request_failed, state_message: "My error message").and_return(1)
        allow(subject).to receive(:schedule).with(task) { raise "My error message" }
        subject.perform(task)
      end
    end
  end
end
