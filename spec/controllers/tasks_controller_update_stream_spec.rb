require 'rails_helper'
require 'support/redis.rb'


RSpec.describe TasksController::UpdateStream do
  include_context 'redis'

  let(:projects) { build_list(:gitlab_project, 5).to_h_by(:id) }
  subject(:tubesock) { instance_double(Tubesock) }

  context 'all tasks' do
    subject { described_class.new(tubesock, projects: projects ) }

    describe '.send_initial_state' do
      it 'sends data' do
        project_id = projects.keys.first
        build_request = create(:build_request, project_id: project_id)
        task1 = create(:task, build_request: build_request)
        task2 = create(:task, build_request: build_request)
        non_project_task = create(:task, build_request_id: -1)

        # First task
        expect(subject).to receive(:send_data).with(task1.id, {
          build: {
            id: task1.build_request.id,
            name: [ projects[project_id][:namespace][:name], projects[project_id][:name] ],
            ref: task1.build_request.ref
          },
          state: 'fresh'
        })

        # Second task
        expect(subject).to receive(:send_data).with(task2.id, anything)

        # Non project task
        expect(subject).to receive(:send_data).with(non_project_task.id, anything)

        # Subscription marker
        expect(subject).to receive(:send_data).with(nil, :subscribed)

        subject.send_initial_state
      end
    end

    describe '.process_message' do
      it 'handles invalid json' do
        subject.process_message('project/1/build_request/2/task/3/updates', 'some "invalid data')
      end
    end
  end

  context 'single task (detail)' do
    let(:task) { create(:task, build_request_id: -1) }
    subject { described_class.new(tubesock, projects: projects, task: task ) }

    describe '.send_initial_state' do
      it 'sends data' do
        # Task info
        expect(subject).to receive(:send_data).with(task.id, anything)

        # Subscription marker
        expect(subject).to receive(:send_data).with(nil, :subscribed)

        subject.send_initial_state
      end
    end
  end
end
