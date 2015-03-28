Rails.application.routes.draw do

  post 'webhook' => 'singularity#webhook'
  get 'logspout' => 'logspout#log'

  get 'setup', to: 'setup#index', as: 'setup'
  get 'setup/watch', to: 'setup#watch', as: 'watch_setup'

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

  get 'help/invalid-config', to: 'help#invalid_config'

  get 'login', to: 'login#new', as: 'login'
  get 'login/auth', to: 'login#auth', as: 'login_auth'
  get 'login/callback', to: 'login#callback', as: 'login_callback'
  get 'logout', to: 'login#destroy', as: 'logout'
end
