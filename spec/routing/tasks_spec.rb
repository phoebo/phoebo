require 'rails_helper'

RSpec.describe 'routes for Tasks', type: :routing do

  it '/ redirects to /tasks', type: :request do
    expect(get('/')).to redirect_to('/tasks')
  end

  it do
    expect(get('/tasks')).to route_to('tasks#index')
  end

  it do
    expect(get('/tasks/jan.noha')).to route_to(
      'tasks#index',
      namespace: 'jan.noha'
    )
  end

  it do
    expect(get('/tasks/watch')).to route_to(
      'tasks#index',
      namespace: 'watch'
    )
  end

  it do
    expect(get('/tasks/jan.noha/awesome_project')).to route_to(
      'tasks#index',
      namespace: 'jan.noha', project: 'awesome_project'
    )
  end

  it do
    expect(get('/tasks/jan.noha/watch')).to route_to(
      'tasks#index',
      namespace: 'jan.noha', project: 'watch'
    )
  end

  it do
    expect(get('/tasks/jan.noha/awesome_project/87e9d07e')).to route_to(
      'tasks#index',
      namespace: 'jan.noha', project: 'awesome_project', build_ref: '87e9d07e'
    )
  end

  it do
    expect(get('/tasks/jan.noha/awesome_project/watch')).to route_to(
      'tasks#index',
      namespace: 'jan.noha', project: 'awesome_project', build_ref: 'watch'
    )
  end

  it do
    expect(get('/tasks/jan.noha/awesome_project/87e9d07e/watch')).to route_to(
      'tasks#watch',
      namespace: 'jan.noha', project: 'awesome_project', build_ref: '87e9d07e'
    )
  end

  it do
    expect(get('/tasks/jan.noha/awesome_project/all_builds/watch')).to route_to(
      'tasks#watch',
      namespace: 'jan.noha', project: 'awesome_project'
    )
  end

  it do
    expect(get('/tasks/jan.noha/all_projects/all_builds/watch')).to route_to(
      'tasks#watch',
      namespace: 'jan.noha'
    )
  end

  it do
    expect(get('/tasks/all_groups/all_projects/all_builds/watch')).to route_to(
      'tasks#watch'
    )
  end

  it do
    expect(delete('/tasks/by_id/123')).to route_to(
      'tasks#destroy',
      task_id: '123'
    )
  end
end
