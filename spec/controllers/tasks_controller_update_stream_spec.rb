require 'rails_helper'

RSpec.describe TasksController::UpdateStream do
	subject(:tubesock) {
		tubesock = instance_double(Tubesock)
	}

	context 'all tasks' do
		before {
			allow(described_class).to receive(:redis_factory) do
				psubscription = instance_double(Redis::Subscription)
				allow(psubscription).to receive(:psubscribe).and_yield("task/*/updates", 1)
				allow(psubscription).to receive(:pmessage)

				redis = instance_double(Redis)
				allow(redis).to receive(:psubscribe).with("task/*/updates").and_yield(psubscription)

				redis
			end
		}

		subject {
			described_class.new(tubesock, nil)
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
