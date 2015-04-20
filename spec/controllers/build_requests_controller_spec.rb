require 'rails_helper'

RSpec.describe BuildRequestsController, type: :controller do

  before do
    skip_filter :check_config
    skip_filter :check_setup
    allow(subject).to receive(:broker).and_return(broker)
  end

  context 'existing task' do
    let(:project_info) do
      project_info = build(:project_info)
      project_info.project_set.settings = build(:project_settings)

      project_info
    end

    let(:task) do
      build(:image_build_task, project_id: project_info.id)
    end

    let(:broker) do
      Broker.new([task])
    end

    describe 'GET #show' do
      it do
        allow(ProjectSet).to receive(:for_project).with(task.project_id).and_return(project_info.project_set)

        get :show, request_secret: task.build_secret
        expect(response).to have_http_status(:ok)
      end
    end

    describe 'POST #create_tasks' do
      let(:payload) { load_json('controllers/examples/image_builder.json') }

      it do
        expect(subject).to receive(:new_task).and_return(build(:broker_task))
        expect(subject).to receive(:process_task)

        post :create_tasks, payload.merge({ request_secret: task.build_secret }), format: :json
        expect(response).to have_http_status(:ok)
      end
    end
  end

  context 'non-existing task' do
    let(:broker) do
      Broker.new([])
    end

    let(:non_existing_secret) do
      '91dc3bfb4de5b11d029d376634589b61'
    end

    describe 'GET #show' do
      it do
        get :show, request_secret: non_existing_secret
        expect(response).to have_http_status(:not_found)
      end
    end

    describe 'POST #create_tasks' do
      it do
        post :create_tasks, { request_secret: non_existing_secret }, format: :json
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  context 'without task context' do
    let(:broker) do
      Broker.new([])
    end

    describe 'GET #new' do
       it do
         expect(response).to have_http_status(:ok)
       end
    end
  end


  # describe 'POST #create' do
  #   before do
  #     login_as :user
  #   end

  #   it do
  #     gitlab_projects = subject.current_user.gitlab.user_projects

  #     params = { build_request: {} }
  #     params[:build_request][:project_id] = gitlab_projects.keys.first

  #     expect(redis).to receive(:publish)
  #     expect(ScheduleJob).to receive(:perform_later)

  #     post :create, params

  #     expect(response).to have_http_status(:redirect)
  #   end
  # end
end
