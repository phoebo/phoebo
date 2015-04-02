Rails.application.routes.draw do

  get 'setup', to: 'setup#index', as: 'setup'
  get 'setup/watch', to: 'setup#watch', as: 'watch_setup'

  # Logspout end-point
  get  'logspout/:secret',            to: 'logspout#log',                as: 'logspout'

  # Singularity webhook handlers
  post 'singularity/:secret/request', to: 'singularity#request_webhook', as: 'singularity_request_webhook'
  post 'singularity/:secret/task',    to: 'singularity#task_webhook',    as: 'singularity_task_webhook'
  post 'singularity/:secret/deploy',  to: 'singularity#deploy_webhook',  as: 'singularity_deploy_webhook'

  resources :tasks do
    get 'watch', on: :collection

    member do
      get 'watch'
      get 'run'
    end
  end

  root to: redirect('tasks')

  resources :projects, only: :index, param: :project_id do
    get 'refresh', on: :collection

    member do
      get 'enable'
      resource :build_requests, only: [ :new ], as: :project_build_request
    end
  end

  resources :build_requests, only: [ :new, :create ]
  resources :build_requests, only: [ :show ], param: :request_secret
  post 'build_requests/:request_secret/tasks', to: 'build_requests#create_tasks' , as: 'build_request_tasks'

  get 'help/invalid-config', to: 'help#invalid_config'

  get 'login', to: 'login#new', as: 'login'
  get 'login/auth', to: 'login#auth', as: 'login_auth'
  get 'login/callback', to: 'login#callback', as: 'login_callback'
  get 'logout', to: 'login#destroy', as: 'logout'
  delete 'logout', to: 'login#destroy'
end
