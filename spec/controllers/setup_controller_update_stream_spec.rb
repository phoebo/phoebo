require 'rails_helper'
require 'support/redis.rb'

RSpec.describe SetupController::UpdateStream do
  include_context 'redis'

  let(:tubesock) { instance_double(Tubesock) }
  subject { described_class.new(tubesock) }

  let(:initial_state) do
    { state: SetupJob::STATE_WORKING }.to_json
  end

  let(:later_state) do
    { state: SetupJob::STATE_FAILED, state_message: "Some error" }.to_json
  end

  it 'sends data' do
    redis_subscription = instance_double(Redis::Subscription)
    allow(redis_subscription).to receive(:subscribe).and_yield
    allow(redis_subscription).to receive(:message).and_yield("", later_state)

    allow(redis).to receive(:subscribe).and_yield(redis_subscription)
    allow(redis).to receive(:dup) {
      redis2 = instance_double(Redis)
      allow(redis2).to receive(:get).and_return(initial_state)
      allow(redis2).to receive(:disconnect!)
      redis2
    }

    expect(tubesock).to receive(:send_data).with(initial_state)
    expect(tubesock).to receive(:send_data).with(later_state)

    subject.run
  end
end
