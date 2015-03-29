require 'rails_helper'
require 'support/redis.rb'

RSpec.describe SingularityController, type: :controller do
  include_context 'redis'

  let(:secret) { 'f989faa676dc1493b1b813e0c87c6fae' }

  before do
    allow_any_instance_of(Phoebo::Application).to receive(:setup_completed?).and_return(true)
  end

  def create_payload(template)
    data = template.dup
    data[:secret] = secret
    data
  end

  # ----------------------------------------------------------------------------

  let(:task_id) { 5 }
  let(:task_mesos_id) { 'phoebo-5-2-1427645113738-1-mesos.local-DEFAULT' }

  let(:task_template) do
    data = nil
    File.open(File.expand_path('../examples/singularity_task_webhook.json', __FILE__), 'r') do |f|
      data = JSON.load(f, nil, symbolize_names: true)
    end
    data
  end

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
      expect(subject).to receive(:update_task).with(task_id,
        mesos_id: task_mesos_id,
        state: :launched
      )

      post :task, create_payload(payload_task_launched), format: :json
      expect(response).to have_http_status(:ok)
    end

    it 'handles TASK_FAILED' do
      expect(subject).to receive(:update_task).with(task_id,
        mesos_id: task_mesos_id,
        state: :failed,
        state_message: payload_task_failed[:taskUpdate][:statusMessage]
      )

      post :task, create_payload(payload_task_failed), format: :json
      expect(response).to have_http_status(:ok)
    end
  end

  # ----------------------------------------------------------------------------

  let(:deploy_task_id) { 8 }

  let(:deploy_template) do
    data = nil
    File.open(File.expand_path('../examples/singularity_deploy_webhook.json', __FILE__), 'r') do |f|
      data = JSON.load(f, nil, symbolize_names: true)
    end
    data
  end

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
      post :deploy, create_payload(payload_deploy_starting), format: :json
      expect(response).to have_http_status(:ok)
    end

    it 'handles deploy FINISHED' do
      expect(subject).to receive(:update_task).with(deploy_task_id, state: :deployed)
      post :deploy, create_payload(payload_deploy_finished), format: :json
      expect(response).to have_http_status(:ok)
    end
  end

  # ----------------------------------------------------------------------------

  let(:task) { create(:task) }
  let(:redis_key) { Redis.composite_key('task', task.id, 'updates') }

  describe '.update_task' do
    it 'updates DB record and publishes update to Redis' do
      update = {
        mesos_id: 'phoebo-5-2-1427645113738-1-mesos.local-DEFAULT',
        state: :failed,
        state_message: 'Command exited with status 127'
      }

      expect(redis).to receive(:publish).with(redis_key, update.to_json)
      subject.send(:update_task, task.id, update)

      modified_task = Task.find(task.id)
      expect(modified_task.failed?).to be true
      expect(modified_task.state_message).to eq(update[:state_message])
    end
  end
end
