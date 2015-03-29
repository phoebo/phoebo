require 'rails_helper'
require 'support/redis.rb'


RSpec.describe TasksController::UpdateStream do
  include_context 'redis'

  subject(:tubesock) { instance_double(Tubesock) }

  context 'all tasks' do
    subject { described_class.new(tubesock, nil) }

    before {
      psubscription = instance_double(Redis::Subscription)
      allow(psubscription).to receive(:psubscribe).and_yield("task/*/updates", 1)
      allow(psubscription).to receive(:pmessage)

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
