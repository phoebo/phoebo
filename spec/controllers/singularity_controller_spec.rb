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

  let(:task) do
    build(:broker_task, request_id: 'phoebo-1429653396-1')
  end

  let(:broker) do
    Broker.new([task])
  end

  before do
    allow(subject).to receive(:broker).and_return(broker)
  end

  # ----------------------------------------------------------------------------

  describe 'POST task' do
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

    it 'handles TASK_LAUNCHED' do
      expect(subject.broker).to receive(:update_task).with(task.id)

      post :task_webhook, create_payload(payload_task_launched), format: :json
      expect(response).to have_http_status(:ok)
    end

    it 'handles TASK_FAILED' do
      expect(subject.broker).to receive(:update_task).with(task.id)

      post :task_webhook, create_payload(payload_task_failed), format: :json
      expect(response).to have_http_status(:ok)
    end
  end

  # ----------------------------------------------------------------------------

  describe 'POST deploy' do
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

    it 'handles deploy STARTING' do
      expect(subject.broker).to receive(:update_task).with(task.id)
      post :deploy_webhook, create_payload(payload_deploy_starting), format: :json
      expect(response).to have_http_status(:ok)
    end

    it 'handles deploy FINISHED' do
      expect(subject.broker).to receive(:update_task).with(task.id)
      post :deploy_webhook, create_payload(payload_deploy_finished), format: :json
      expect(response).to have_http_status(:ok)
    end
  end

  # ----------------------------------------------------------------------------

  describe 'POST request' do
    let(:request_template) { load_json('controllers/examples/singularity_request_webhook.json') }

    let(:payload_request_deleted) do
      data = request_template.dup
      data[:eventType] = 'DELETED'
      data
    end

    it 'handles request DELETED' do
      expect(subject.broker).to receive(:update_task).with(task.id)
      post :request_webhook, create_payload(payload_request_deleted), format: :json
      expect(response).to have_http_status(:ok)
    end
  end

end
