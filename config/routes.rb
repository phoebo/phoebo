Rails.application.routes.draw do

  post 'webhook' => 'singularity#webhook'
  get 'logspout' => 'logspout#log'

  resources :tasks do
    get 'watch', on: :collection

    member do
      get 'watch'
      get 'run'
    end
  end

  root to: 'tasks#index'

  get 'help/invalid-config', to: 'help#invalid_config'

  get 'login', to: 'login#new', as: 'login'
  get 'login/auth', to: 'login#auth', as: 'login_auth'
  get 'login/callback', to: 'login#callback', as: 'login_callback'
  get 'logout', to: 'login#destroy', as: 'logout'
end
