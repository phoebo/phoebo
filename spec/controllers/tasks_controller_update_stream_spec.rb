require 'rails_helper'

RSpec.describe TasksController::UpdateStream do
  subject(:tubesock) { instance_double(Tubesock) }

  context 'all tasks' do
    subject { described_class.new(tubesock, nil) }

    before {
      psubscription = instance_double(Redis::Subscription)
      allow(psubscription).to receive(:psubscribe).and_yield("task/*/updates", 1)
      allow(psubscription).to receive(:pmessage)

      redis = instance_double(Redis)
      allow_any_instance_of(Object).to receive(:with_redis).and_yield(redis)
      allow(redis).to receive(:psubscribe).with("task/*/updates").and_yield(psubscription)
    }

    it 'sends initial data' do
      task = create(:task)
      payload = { "#{task.id}" => { "state" => "fresh" } }
      expect(tubesock).to receive(:send_data).with(payload.to_json)
      subject.run
    end
  end

  context 'single task (detail)' do
    # TODO
  end
end
