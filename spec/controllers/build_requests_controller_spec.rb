require 'rails_helper'
require 'support/redis.rb'

RSpec.describe BuildRequestsController, type: :controller do
  include_context 'redis'

  before do
    skip_filter :check_config
    skip_filter :check_setup
  end

  describe 'GET #show' do
    it do
      build_request = create(:build_request)
      get :show, request_secret: build_request.secret
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST #create_tasks' do
    let(:payload) { load_json('controllers/examples/image_builder.json') }

    it do
      build_request = create(:build_request)
      post :create_tasks, payload.merge({ request_secret: build_request.secret }), format: :json
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET #new' do
    it do
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST #create' do
    before do
      login_as :user
    end

    it do
      gitlab_projects = subject.current_user.gitlab.user_projects

      params = { build_request: {} }
      params[:build_request][:project_id] = gitlab_projects.keys.first

      expect(redis).to receive(:publish)
      expect(ScheduleJob).to receive(:perform_later)

      post :create, params

      expect(response).to have_http_status(:redirect)
    end
  end
end
