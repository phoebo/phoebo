Rails.application.routes.draw do

  get 'setup', to: 'setup#index', as: 'setup'
  get 'setup/watch', to: 'setup#watch', as: 'watch_setup'

  # Logspout end-point
  get  'logspout/:secret',            to: 'logspout#log',                as: 'logspout'

  # Singularity webhook handlers
  post 'singularity/:secret/request', to: 'singularity#request_webhook', as: 'singularity_request_webhook'
  post 'singularity/:secret/task',    to: 'singularity#task_webhook',    as: 'singularity_task_webhook'
  post 'singularity/:secret/deploy',  to: 'singularity#deploy_webhook',  as: 'singularity_deploy_webhook'

  # Project settings
  scope :project_settings do
    root to: 'project_settings#show', as: 'projects_settings'
    post '/', to: 'project_settings#update'

    constraints(namespace: /[^\/]+/, project: /[^\/]+/) do
      get  ':namespace',          to: 'project_settings#show',   as: 'namespace_settings'
      post ':namespace',          to: 'project_settings#update'
      get  ':namespace/:project', to: 'project_settings#show',   as: 'project_settings'
      post ':namespace/:project', to: 'project_settings#update'
    end
  end

  # Task index and watch stream
  scope :tasks do
    constraints(task_id: /[0-9]+/) do
      resources :by_id, as: :task_by_id, controller: :tasks, only: :destroy, param: :task_id
    end

    constraints(namespace: /[^\/]+/, project: /[^\/]+/, build_ref: /[^\/]+/) do
      get 'all_groups/all_projects/all_builds/watch',
        to: 'tasks#watch', as: 'watch_tasks'

      get ':namespace/all_projects/all_builds/watch',
        to: 'tasks#watch', as: 'watch_namespace_tasks'

      get ':namespace/:project/all_builds/watch',
        to: 'tasks#watch', as: 'watch_project_tasks'

      get ':namespace/:project/:build_ref/watch',
        to: 'tasks#watch', as: 'watch_build_tasks'

      root                                  to: 'tasks#index', as: 'tasks'
      get ':namespace',                     to: 'tasks#index', as: 'namespace_tasks'
      get ':namespace/:project',            to: 'tasks#index', as: 'project_tasks'
      get ':namespace/:project/:build_ref', to: 'tasks#index', as: 'build_tasks'
    end
  end

  # Root -> task index
  root to: redirect('tasks')

  # Projects
  resources :projects, only: :index, param: :project_id do
    get 'refresh', on: :collection

    member do
      get 'enable'
      get 'disable'
      get 'commits'
      resource :build_requests, only: [ :new ], as: :project_build_request
    end
  end

  resources :build_requests, only: [ :new, :create ]
  resources :build_requests, only: [ :show ], param: :request_secret
  post 'build_requests/:request_secret/tasks', to: 'build_requests#create_tasks' , as: 'build_request_tasks'

  get 'help/invalid_config', to: 'help#invalid_config'
  get 'help/no_projects', to: 'help#no_projects'

  get 'login', to: 'login#new', as: 'login'
  get 'login/auth', to: 'login#auth', as: 'login_auth'
  get 'login/callback', to: 'login#callback', as: 'login_callback'
  get 'logout', to: 'login#destroy', as: 'logout'
  delete 'logout', to: 'login#destroy'
end
