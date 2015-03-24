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

  root 'tasks#index'

  get 'help/invalid-config', to: 'help#invalid_config'
end
