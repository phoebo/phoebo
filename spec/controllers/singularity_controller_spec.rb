require 'rails_helper'
require 'support/redis.rb'

RSpec.describe SingularityController, type: :controller do
  include_context 'redis'

  let(:secret) { 'f989faa676dc1493b1b813e0c87c6fae' }

  def create_payload(template)
    data = template.dup
    data[:secret] = secret
    data
  end

  # ----------------------------------------------------------------------------

  let(:task_id) {{ project_id: 39, build_request_id: 47, task_id: 170 }}
  let(:task_mesos_id) { 'phoebo-p39-b47-t170-1-1427988069527-1-mesos.local-DEFAULT' }
  let(:task_template) { load_json('controllers/examples/singularity_task_webhook.json') }

  let(:payload_task_launched) do
    data = task_template.dup
    data[:taskUpdate][:taskState] = 'TASK_LAUNCHED'
    data
  end

  let(:payload_task_failed) do
    data = task_template.dup
    data[:taskUpdate][:taskState] = 'TASK_FAILED'
    data[:taskUpdate][:statusMessage] = 'Command exited with status 127'
    data
  end

  # ----------------------------------------------------------------------------

  describe 'POST task' do
    it 'handles TASK_LAUNCHED' do
      expect(subject).to receive(:update_task).with(task_id, anything)

      post :task_webhook, create_payload(payload_task_launched), format: :json
      expect(response).to have_http_status(:ok)
    end

    it 'handles TASK_FAILED' do
      expect(subject).to receive(:update_task).with(task_id, anything)

      post :task_webhook, create_payload(payload_task_failed), format: :json
      expect(response).to have_http_status(:ok)
    end
  end

  # ----------------------------------------------------------------------------

  let(:deploy_task_id) {{ task_id: 8 }}
  let(:deploy_template) { load_json('controllers/examples/singularity_deploy_webhook.json') }

  let(:payload_deploy_starting) do
    data = deploy_template.dup
    data[:eventType] = 'STARTING'
    data
  end

  let(:payload_deploy_finished) do
    data = deploy_template.dup
    data[:eventType] = 'FINISHED'
    data[:deployResult] = {
      deployState: 'SUCCEEDED',
      message: 'Request not deployable',
      timestamp: 1427652989966
    }
    data
  end

  # ----------------------------------------------------------------------------

  describe 'POST deploy' do
    it 'handles deploy STARTING' do
      expect(subject).to receive(:update_task).with(deploy_task_id, state: :deploying)
      post :deploy_webhook, create_payload(payload_deploy_starting), format: :json
      expect(response).to have_http_status(:ok)
    end

    it 'handles deploy FINISHED' do
      expect(subject).to receive(:update_task).with(deploy_task_id, state: :deployed)
      post :deploy_webhook, create_payload(payload_deploy_finished), format: :json
      expect(response).to have_http_status(:ok)
    end
  end

  # ----------------------------------------------------------------------------

  let(:request_task_id) {{ task_id: 2 }}
  let(:request_template) { load_json('controllers/examples/singularity_request_webhook.json') }

  let(:payload_request_deleted) do
    data = request_template.dup
    data[:eventType] = 'DELETED'
    data
  end

  # ----------------------------------------------------------------------------

  describe 'POST request' do
    it 'handles request DELETED' do
      expect(subject).to receive(:update_task).with(request_task_id, state: :deleted)
      post :request_webhook, create_payload(payload_request_deleted), format: :json
      expect(response).to have_http_status(:ok)
    end
  end

  # ----------------------------------------------------------------------------

  let(:task) { create(:task) }
  let(:redis_key) { Redis.key_for_task_updates(task_id: task.id) }

  describe '.update_task' do
    it 'updates DB record and publishes update to Redis' do
      update = {
        mesos_id: 'phoebo-p1-b1-t5-2-1427645113738-1-mesos.local-DEFAULT',
        state: :failed,
        state_message: 'Command exited with status 127'
      }

      expect(redis).to receive(:publish).with(redis_key, update.to_json)
      subject.send(:update_task, { task_id: task.id }, update)

      modified_task = Task.find(task.id)
      expect(modified_task.failed?).to be true
      expect(modified_task.state_message).to eq(update[:state_message])
    end
  end
end
