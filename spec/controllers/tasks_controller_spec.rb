require 'rails_helper'

RSpec.describe TasksController, type: :controller do

  before do
    login_as :user
    skip_filter :check_config
    skip_filter :check_setup
  end

  describe 'GET watch' do
    # Tubesock mock
    let(:tubesock) do
      tubesock = instance_double(Tubesock)
      allow(subject).to receive(:hijack).and_yield(tubesock)
      allow(tubesock).to receive(:onclose).and_yield
      tubesock
    end

    # UpdateStream mock
    let(:update_stream) do
      update_stream = instance_double(TasksController::UpdateStream)
      allow(update_stream).to receive(:run)
      update_stream
    end

    before do
      # Tubesock mock
      tubesock

      # Thread mock
      thread = instance_double(Thread)
      allow(Thread).to receive(:new).and_return(thread).and_yield()
      allow(thread).to receive(:kill)
    end

    context 'all tasks' do
      it 'creates an update stream thread' do
        args = [ tubesock, { projects: subject.current_user.gitlab.user_projects } ]
        allow(TasksController::UpdateStream).to receive(:new).with(*args).and_return(update_stream)
        get :watch
      end
    end

    context 'project tasks' do
      # TODO
    end

    context 'build request tasks' do
      # TODO
    end

    context 'a single task' do
      it 'creates an update stream thread' do
        task = create(:task)
        args = [ tubesock, { projects: subject.current_user.gitlab.user_projects, task: task } ]
        allow(TasksController::UpdateStream).to receive(:new).with(*args).and_return(update_stream)
        get :watch, id: task.id
      end
    end
  end
end