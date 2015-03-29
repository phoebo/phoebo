require 'rails_helper'
require 'support/redis.rb'

RSpec.describe SingularityController, type: :controller do
  include_context 'redis'

  let(:task) do
    create(:task)
  end

  let(:notification_template) do
    data = nil
    File.open(File.expand_path('../examples/singularity_webhook_notification.json', __FILE__), 'r') do |f|
      data = JSON.load(f, nil, symbolize_names: true)
    end

    data[:taskUpdate][:taskId][:requestId] = task.request_id
    data
  end

  let(:payload_task_launched) do
    data = notification_template.dup
    data[:taskUpdate][:taskState] = 'TASK_LAUNCHED'
    data
  end

  let(:payload_task_running) do
    data = notification_template.dup
    data[:taskUpdate][:taskState] = 'TASK_RUNNING'
    data
  end

  let(:payload_task_finished) do
    data = notification_template.dup
    data[:taskUpdate][:taskState] = 'TASK_FINISHED'
    data
  end

  let(:payload_task_failed) do
    data = notification_template.dup
    data[:taskUpdate][:taskState] = 'TASK_FAILED'
    data[:taskUpdate][:statusMessage] = 'Command exited with status 127'
    data
  end

  before do
    allow_any_instance_of(Phoebo::Application).to receive(:setup_completed?).and_return(true)
  end

  # ----------------------------------------------------------------------------

  describe 'POST webhook' do
    it 'handles TASK_LAUNCHED' do
      data = payload_task_launched

      redis_key = Redis.composite_key('task', task.id, 'updates')
      redis_payload = { mesos_id: data[:taskUpdate][:taskId][:id], state: :launched }
      expect(redis).to receive(:publish).with(redis_key, redis_payload.to_json)

      post :webhook, data, format: :json
      expect(response).to have_http_status(:ok)
    end
  end
end
